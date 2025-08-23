import SwiftUI
import SwiftData

struct StaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(1.0) // Always full opacity
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Transcription.timestamp, order: .reverse)]) private var notes: [Transcription]

    @StateObject private var recorder = AudioRecorder()
    @State private var isTranscribing: Bool = false
    @State private var searchText: String = ""
    @State private var showingRecordSheet: Bool = false
    @State private var showingNoModesAlert: Bool = false
    @State private var currentRecordingNote: Transcription?
    private let postProcessor = LLMPostProcessor()

    var filteredNotes: [Transcription] {
        notes.filter { note in
            searchText.isEmpty ||
            note.text.localizedCaseInsensitiveContains(searchText) ||
            (note.enhancedText ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    init() {}

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("VoiceInk")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: SettingsView()) { Image(systemName: "gearshape") }
                    }
                    

                }
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
                .sheet(isPresented: $showingRecordSheet) {
                    RecordSheetView(recorder: recorder, onStopAndTranscribe: { completion in
                        stopAndTranscribe { result, note in
                            completion(result, note)
                        }
                    }, onDismiss: {
                        showingRecordSheet = false
                    })
                }
                .safeAreaInset(edge: .bottom) { recordBar }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            List {
                ForEach(filteredNotes) { note in
                    NavigationLink(destination: NoteDetailView(note: note)) {
                        NoteRowView(note: note)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(.insetGrouped)
        }
    }

    private var recordBar: some View {
        HStack {
            Button(action: {
                if AppSettings.shared.modes.isEmpty {
                    showingNoModesAlert = true
                } else {
                    showingRecordSheet = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isTranscribing ? "waveform" : "mic.fill")
                    Text(isTranscribing ? "Processing..." : "Start Recording")
                        .font(.headline)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.label))
                .foregroundStyle(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(StaticButtonStyle())
            .disabled(isTranscribing)
        }
        .padding(.horizontal)
        .padding(.bottom)
        .alert("No Modes Found", isPresented: $showingNoModesAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please create a new mode in Settings before recording.")
        }
    }

    private func stopAndTranscribe(completion: @escaping (Result<String, Error>, Transcription?) -> Void) {
        recorder.stopRecording()
        guard let fileURL = recorder.currentRecordingURL else { return }
        isTranscribing = true
        
        // ALWAYS preserve the audio file first, regardless of what happens next
        // Store relative path instead of absolute path for persistence across app launches
        let audioFileName = fileURL.lastPathComponent
        let recordingDuration = recorder.currentDuration
        
        transcribeAudio(audioFilePath: audioFileName, recordingDuration: recordingDuration, completion: completion)
    }
    
    private func transcribeAudio(audioFilePath: String, recordingDuration: Double, completion: @escaping (Result<String, Error>, Transcription?) -> Void) {
        
        Task {
            defer { 
                isTranscribing = false
                // Clean up recorder state but keep the audio file
                recorder.currentRecordingURL = nil
                recorder.currentDuration = 0
            }
            
            let settings = AppSettings.shared
            
            // Use effective settings from selected mode or fallback to legacy settings
            let provider = settings.effectiveTranscriptionProvider
            let apiKey = settings.apiKey(for: provider)
            let model = settings.effectiveTranscriptionModel
            
            // If no API key, save audio with pending status
            guard !apiKey.isEmpty else {
                let note = Transcription(
                    text: "",
                    duration: recordingDuration,
                    audioFileURL: audioFilePath,
                    transcriptionStatus: .pending,
                    transcriptionError: "No API key configured"
                )
                modelContext.insert(note)
                try? modelContext.save()
                completion(.failure(NSError(domain: "VoiceInk", code: 1, userInfo: [NSLocalizedDescriptionKey: "No API key configured"])), note)
                return
            }
            
            do {
                // Resolve the relative path to absolute path for transcription
                let recordingsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("Recordings")
                let fileURL = recordingsDir.appendingPathComponent(audioFilePath)
                let service = TranscriptionServiceFactory.service(for: provider)
                let rawText = try await service.transcribeAudioFile(apiBaseURL: provider.baseURL, apiKey: apiKey, model: model, fileURL: fileURL, language: nil)
                // Clean up transcription: trim whitespace and normalize line breaks
                let cleanedText = rawText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n\n+", with: "\n\n", options: .regularExpression) // Remove excessive line breaks
                    .replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression) // Normalize multiple spaces/tabs to single space
                
                var finalText = cleanedText
                var enhancedText: String? = nil
                
                // Optional post-processing using effective settings
                var postProcessingError: String? = nil
                if settings.effectiveIsPostProcessingEnabled {
                    let ppPrompt = settings.effectiveCustomPrompt
                    if !ppPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let llmProvider = settings.effectivePostProcessingProvider
                        let llmKey = settings.apiKey(for: llmProvider)
                        let llmModel = settings.effectivePostProcessingModel
                        if !llmKey.isEmpty {
                            do {
                                finalText = try await postProcessor.postProcessTranscript(provider: llmProvider, apiKey: llmKey, model: llmModel, prompt: ppPrompt, transcript: cleanedText)
                                enhancedText = finalText
                            } catch {
                                // Post-processing failed, but transcription succeeded
                                postProcessingError = "Post-processing failed: \(error.localizedDescription)"
                                // Still use the cleaned transcription text
                                finalText = cleanedText
                            }
                        }
                    }
                }
                
                let note = Transcription(
                    text: cleanedText,
                    duration: recordingDuration,
                    enhancedText: enhancedText,
                    audioFileURL: audioFilePath,
                    transcriptionModelName: model,
                    aiEnhancementModelName: settings.effectiveIsPostProcessingEnabled ? settings.effectivePostProcessingModel : nil,
                    transcriptionStatus: .completed,
                    transcriptionError: postProcessingError
                )
                modelContext.insert(note)
                try? modelContext.save()
                
                // Return success with transcript
                completion(.success(finalText), note)
            } catch {
                // Save the recording even if transcription failed
                let note = Transcription(
                    text: "",
                    duration: recordingDuration,
                    audioFileURL: audioFilePath,
                    transcriptionStatus: .failed,
                    transcriptionError: error.localizedDescription
                )
                modelContext.insert(note)
                try? modelContext.save()
                
                // Return error
                completion(.failure(error), note)
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets { modelContext.delete(filteredNotes[index]) }
        }
    }

    // Star/share removed

    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d", m, r)
    }
}

#Preview {
    NotesListView()
        .modelContainer(for: [Transcription.self])
}



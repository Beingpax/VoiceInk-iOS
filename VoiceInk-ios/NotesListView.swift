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
    @Query(sort: [SortDescriptor(\Note.createdAt, order: .reverse)]) private var notes: [Note]

    @StateObject private var recorder = AudioRecorder()
    @State private var isTranscribing: Bool = false
    @State private var searchText: String = ""
    @State private var showingRecordSheet: Bool = false
    @State private var currentRecordingNote: Note?
    private let postProcessor = LLMPostProcessor()

    var filteredNotes: [Note] {
        notes.filter { searchText.isEmpty || $0.transcript.localizedCaseInsensitiveContains(searchText) }
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
            Button(action: { showingRecordSheet = true }) {
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
    }

    private func stopAndTranscribe(completion: @escaping (Result<String, Error>, Note?) -> Void) {
        recorder.stopRecording()
        guard let fileURL = recorder.currentRecordingURL else { return }
        isTranscribing = true
        
        // ALWAYS preserve the audio file first, regardless of what happens next
        // Store relative path instead of absolute path for persistence across app launches
        let audioFileName = fileURL.lastPathComponent
        let recordingDuration = recorder.currentDuration
        
        transcribeAudio(audioFilePath: audioFileName, recordingDuration: recordingDuration, completion: completion)
    }
    
    private func transcribeAudio(audioFilePath: String, recordingDuration: Double, completion: @escaping (Result<String, Error>, Note?) -> Void) {
        
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
                let note = Note(
                    transcript: "",
                    audioFilePath: audioFilePath,
                    durationSeconds: recordingDuration,
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
                            } catch {
                                // Post-processing failed, but transcription succeeded
                                postProcessingError = "Post-processing failed: \(error.localizedDescription)"
                                // Still use the cleaned transcription text
                                finalText = cleanedText
                            }
                        }
                    }
                }
                
                let note = Note(
                    transcript: finalText,
                    audioFilePath: audioFilePath,
                    durationSeconds: recordingDuration,
                    transcriptionStatus: .completed,
                    transcriptionError: postProcessingError
                )
                modelContext.insert(note)
                try? modelContext.save()
                
                // Return success with transcript
                completion(.success(finalText), note)
            } catch {
                // Save the recording even if transcription failed
                let note = Note(
                    transcript: "",
                    audioFilePath: audioFilePath,
                    durationSeconds: recordingDuration,
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
        .modelContainer(for: [Note.self])
}



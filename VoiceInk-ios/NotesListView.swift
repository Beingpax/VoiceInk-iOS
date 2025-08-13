import SwiftUI
import SwiftData

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Note.createdAt, order: .reverse)]) private var notes: [Note]

    @StateObject private var recorder = AudioRecorder()
    @State private var isTranscribing: Bool = false
    @State private var searchText: String = ""
    @State private var showingRecordSheet: Bool = false
    @State private var recordSheetView: RecordSheetView?
    private let service = GroqTranscriptionService()
    private let postProcessor = LLMPostProcessor()

    var filteredNotes: [Note] {
        notes.filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) || $0.transcript.localizedCaseInsensitiveContains(searchText) }
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
                        stopAndTranscribe(completion: completion)
                    })
                    .id(showingRecordSheet) // Reset state when sheet reopens
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
                    Image(systemName: "record.circle.fill")
                    Text("Record")
                        .font(.headline)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.label))
                .foregroundStyle(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isTranscribing)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private func stopAndTranscribe(completion: @escaping (Result<String, Error>) -> Void) {
        recorder.stopRecording()
        guard let fileURL = recorder.currentRecordingURL else { return }
        isTranscribing = true
        Task {
            defer { isTranscribing = false }
            let settings = AppSettings.shared
            
            // Use effective settings from selected mode or fallback to legacy settings
            let provider = settings.effectiveTranscriptionProvider
            let apiKey = settings.apiKey(for: provider)
            let model = settings.effectiveTranscriptionModel
            guard !apiKey.isEmpty else { return }
            
            do {
                let rawText = try await service.transcribeAudioFile(apiBaseURL: provider.baseURL, apiKey: apiKey, model: model, fileURL: fileURL, language: nil)
                // Clean up transcription: trim whitespace and normalize line breaks
                let cleanedText = rawText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n\n+", with: "\n\n", options: .regularExpression) // Remove excessive line breaks
                    .replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression) // Normalize multiple spaces/tabs to single space
                
                var finalText = cleanedText
                
                // Optional post-processing using effective settings
                let ppPrompt = settings.effectiveCustomPrompt
                if !ppPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let llmProvider = settings.effectivePostProcessingProvider
                    let llmKey = settings.apiKey(for: llmProvider)
                    let llmModel = settings.effectivePostProcessingModel
                    if !llmKey.isEmpty {
                        do {
                            finalText = try await postProcessor.postProcessTranscript(provider: llmProvider, apiKey: llmKey, model: llmModel, prompt: ppPrompt, transcript: cleanedText)
                        } catch {
                            // Fall back silently to raw text
                        }
                    }
                }
                
                let note = Note(
                    title: "New note",
                    transcript: finalText,
                    audioFilePath: fileURL.path,
                    durationSeconds: recorder.currentDuration
                )
                modelContext.insert(note)
                
                // Don't discard the audio file - keep it for playback
                recorder.stopRecording()
                recorder.currentRecordingURL = nil
                recorder.currentDuration = 0
                
                // Return success with transcript
                completion(.success(finalText))
            } catch {
                let note = Note(title: "New note", transcript: "Transcription failed: \(error.localizedDescription)")
                modelContext.insert(note)
                // Only discard on error
                recorder.discard()
                
                // Return error
                completion(.failure(error))
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



import SwiftUI
import SwiftData

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Note.createdAt, order: .reverse)]) private var notes: [Note]

    @StateObject private var recorder = AudioRecorder()
    @State private var isTranscribing: Bool = false
    @State private var searchText: String = ""
    @State private var selectedFilter: Filter = .all
    @State private var showingRecordSheet: Bool = false
    private let service = GroqTranscriptionService()
    private let postProcessor = LLMPostProcessor()

    enum Filter: String, CaseIterable { case all = "All", shared = "Shared", starred = "Starred" }

    var filteredNotes: [Note] {
        let base = notes.filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) || $0.transcript.localizedCaseInsensitiveContains(searchText) }
        switch selectedFilter {
        case .all: return base
        case .shared: return base.filter { $0.isShared }
        case .starred: return base.filter { $0.isStarred }
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
                    RecordSheetView(recorder: recorder, onStopAndTranscribe: stopAndTranscribe)
                }
                .safeAreaInset(edge: .bottom) { recordBar }
        }
    }

    private var content: some View {
        VStack(spacing: 8) {
            filterControl
            List {
                ForEach(filteredNotes) { note in
                    NoteRowView(note: note, onToggleStar: { toggleStar(note) }, onToggleShare: { toggleShare(note) })
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(.insetGrouped)
        }
    }

    private var filterControl: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(Filter.allCases, id: \.self) { f in Text(f.rawValue).tag(f) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
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

    private func stopAndTranscribe() {
        recorder.stopRecording()
        guard let fileURL = recorder.currentRecordingURL else { return }
        isTranscribing = true
        Task {
            defer { isTranscribing = false }
            let provider = AppSettings.shared.selectedProvider
            let apiKey = AppSettings.shared.apiKey(for: provider)
            let model = AppSettings.shared.preferredModel
            guard !apiKey.isEmpty else { return }
            do {
                let text = try await service.transcribeAudioFile(apiBaseURL: provider.baseURL, apiKey: apiKey, model: model, fileURL: fileURL, language: nil)
                var finalText = text
                // Optional post-processing
                let ppPrompt = AppSettings.shared.postProcessPrompt
                if !ppPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let llmProvider = AppSettings.shared.llmProvider
                    let llmKey = AppSettings.shared.apiKey(for: llmProvider)
                    let llmModel = AppSettings.shared.llmModel
                    if !llmKey.isEmpty {
                        do {
                            finalText = try await postProcessor.postProcessTranscript(provider: llmProvider, apiKey: llmKey, model: llmModel, prompt: ppPrompt, transcript: text)
                        } catch {
                            // Fall back silently to raw text
                        }
                    }
                }
                let note = Note(title: "New note", transcript: finalText, audioFilePath: fileURL.path, durationSeconds: recorder.currentDuration)
                modelContext.insert(note)
            } catch {
                let note = Note(title: "New note", transcript: "Transcription failed: \(error.localizedDescription)")
                modelContext.insert(note)
            }
            recorder.discard()
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets { modelContext.delete(filteredNotes[index]) }
        }
    }

    private func toggleStar(_ note: Note) {
        note.isStarred.toggle()
    }

    private func toggleShare(_ note: Note) {
        note.isShared.toggle()
    }

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



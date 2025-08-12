import SwiftUI
import SwiftData

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \[SortDescriptor(\.createdAt, order: .reverse)\]) private var notes: [Note]

    @StateObject private var recorder = AudioRecorder()
    @State private var isTranscribing: Bool = false
    @State private var searchText: String = ""
    @State private var selectedFilter: Filter = .all
    private let service = GroqTranscriptionService()

    enum Filter: String, CaseIterable { case all = "All", shared = "Shared", starred = "Starred" }

    var filteredNotes: [Note] {
        let base = notes.filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) || $0.transcript.localizedCaseInsensitiveContains(searchText) }
        switch selectedFilter {
        case .all: return base
        case .shared: return base.filter { $0.isShared }
        case .starred: return base.filter { $0.isStarred }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mimic search bar and filter chips
                HStack {
                    HStack { Image(systemName: "magnifyingglass"); TextField("Search", text: $searchText) }
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .padding(8)
                    }
                }.padding([.horizontal, .top])

                HStack(spacing: 8) {
                    ForEach(Filter.allCases, id: \.self) { f in
                        Button(action: { selectedFilter = f }) {
                            Text(f.rawValue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedFilter == f ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                }.padding(.horizontal)

                List {
                    ForEach(filteredNotes) { note in
                        NavigationLink(value: note.id) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(note.title).font(.headline)
                                Text(note.transcript.isEmpty ? "No audible content detected." : note.transcript)
                                    .lineLimit(2)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 16) {
                                    Label(note.createdAt, systemImage: "calendar")
                                        .labelStyle(.titleAndIcon)
                                        .font(.caption)
                                    if note.durationSeconds > 0 {
                                        Label(timeString(note.durationSeconds), systemImage: "play.circle")
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteItems)
                }

                // Bottom record bar
                recordBar
            }
            .navigationTitle("Voicenotes")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var recordBar: some View {
        VStack {
            if recorder.isRecording {
                Button(action: stopAndTranscribe) {
                    HStack { Image(systemName: "stop.fill"); Text("Stop • \(timeString(recorder.currentDuration))") }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .padding()
            } else {
                Button(action: startRecording) {
                    HStack { Image(systemName: "record.circle"); Text(isTranscribing ? "Transcribing..." : "Record") }
                }
                .disabled(isTranscribing)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.label))
                .foregroundStyle(Color(.systemBackground))
                .clipShape(Capsule())
                .padding()
            }
        }
    }

    private func startRecording() {
        do { try recorder.startRecording() } catch { print("Record error: \(error)") }
    }

    private func stopAndTranscribe() {
        recorder.stopRecording()
        guard let fileURL = recorder.currentRecordingURL else { return }
        isTranscribing = true
        Task {
            defer { isTranscribing = false }
            let apiKey = AppSettings.shared.openAICompatibleAPIKey
            guard !apiKey.isEmpty else { return }
            do {
                let text = try await service.transcribeAudioFile(apiKey: apiKey, fileURL: fileURL, language: nil)
                let note = Note(title: "New note", transcript: text, audioFilePath: fileURL.path, durationSeconds: recorder.currentDuration)
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



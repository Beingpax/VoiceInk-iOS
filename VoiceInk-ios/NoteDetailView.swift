import SwiftUI

struct NoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let note: Note

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(note.title.isEmpty ? "New note" : note.title)
                    .font(.title2.weight(.semibold))
                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // Audio player (only show if audio file exists)
                if let audioPath = note.audioFilePath,
                   !audioPath.isEmpty,
                   FileManager.default.fileExists(atPath: audioPath) {
                    AudioPlayerView(audioFilePath: audioPath, duration: note.durationSeconds)
                }

                Text(note.transcript.isEmpty ? "No content" : note.transcript)
                    .font(.body)
                    .textSelection(.enabled)
            }
            .padding()
        }
        .navigationTitle("Note")
        .navigationBarTitleDisplayMode(.inline)
    }
}



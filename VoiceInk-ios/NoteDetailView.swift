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

                // Post-processing badge removed for leaner UI

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



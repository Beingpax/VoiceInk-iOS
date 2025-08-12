import SwiftUI

struct NoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let note: Note

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(note.title.isEmpty ? "New note" : note.title)
                        .font(.title2.weight(.semibold))
                    Spacer()
                    if note.isStarred { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                }
                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if note.isPostProcessed {
                    Label("Post-processed by \(note.postProcessorProvider ?? "LLM") • \(note.postProcessorModel ?? "")", systemImage: "wand.and.stars")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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

#Preview {
    let n = Note(title: "Sample", transcript: "This is a sample transcript.", durationSeconds: 42, isPostProcessed: true, postProcessorProvider: "Groq", postProcessorModel: "llama-3.1-8b-instant")
    return NavigationStack { NoteDetailView(note: n) }
}



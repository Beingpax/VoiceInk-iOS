import SwiftUI

struct NoteRowView: View {
    let note: Note
    let onToggleStar: () -> Void
    let onToggleShare: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "waveform")
                .foregroundStyle(.accent)
                .imageScale(.large)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(note.title.isEmpty ? "New note" : note.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    if note.isStarred { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                    if note.isShared { Image(systemName: "person.2.fill").foregroundStyle(.secondary) }
                }
                Text(note.transcript.isEmpty ? "No audible content detected." : note.transcript)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Label(note.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if note.durationSeconds > 0 {
                        Label(timeString(note.durationSeconds), systemImage: "play.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: onToggleStar) {
                Label(note.isStarred ? "Unstar" : "Star", systemImage: note.isStarred ? "star.slash" : "star")
            }.tint(.yellow)
        }
        .swipeActions(edge: .leading) {
            Button(action: onToggleShare) {
                Label(note.isShared ? "Unshare" : "Share", systemImage: note.isShared ? "person.fill.xmark" : "square.and.arrow.up")
            }.tint(.blue)
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
    let sample = Note(title: "Meeting notes", transcript: "Discussed quarterly roadmap and action items.", durationSeconds: 74)
    return List { NoteRowView(note: sample, onToggleStar: {}, onToggleShare: {}) }
}



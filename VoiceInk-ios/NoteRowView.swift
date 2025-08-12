import SwiftUI

struct NoteRowView: View {
    let note: Note
    // Callbacks removed since star/share are gone
    let onToggleStar: () -> Void = {}
    let onToggleShare: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "waveform")
                .imageScale(.large)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(note.title.isEmpty ? "New note" : note.title)
                    .font(.headline)
                    .lineLimit(1)
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
        // Swipe actions removed with star/share
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



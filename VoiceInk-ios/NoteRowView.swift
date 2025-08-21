import SwiftUI

struct NoteRowView: View {
    let note: Note
    // Callbacks removed since star/share are gone
    let onToggleStar: () -> Void = {}
    let onToggleShare: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(transcriptText)
                .font(.body)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            HStack(spacing: 16) {
                Label(note.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if note.durationSeconds > 0 {
                    Label(timeString(note.durationSeconds), systemImage: "play.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if note.transcriptionStatus == .failed {
                    Label("Failed", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    

    
    private var transcriptText: String {
        switch note.transcriptionStatus {
        case .pending:
            return "Transcription pending..."
        case .failed:
            return "Transcription failed - tap to retry"
        case .completed:
            return note.transcript.isEmpty ? "No audible content detected." : note.transcript
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d", m, r)
    }
}




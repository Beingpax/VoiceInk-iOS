import SwiftUI

struct NoteRowView: View {
    let note: Note
    // Callbacks removed since star/share are gone
    let onToggleStar: () -> Void = {}
    let onToggleShare: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Status icon based on transcription status
            Image(systemName: statusIcon)
                .imageScale(.large)
                .frame(width: 28)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(note.title.isEmpty ? "New note" : note.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if note.transcriptionStatus == .failed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                
                Text(transcriptText)
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
    }
    
    private var statusIcon: String {
        switch note.transcriptionStatus {
        case .pending:
            return "clock"
        case .completed:
            return "waveform"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
    
    private var statusColor: Color {
        switch note.transcriptionStatus {
        case .pending:
            return .orange
        case .completed:
            return .blue
        case .failed:
            return .red
        }
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




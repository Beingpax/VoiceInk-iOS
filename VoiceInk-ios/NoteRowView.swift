import SwiftUI

struct NoteRowView: View {
    let note: Transcription
    // Callbacks removed since star/share are gone
    let onToggleStar: () -> Void = {}
    let onToggleShare: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(transcriptText)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(2)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            HStack(spacing: 8) {
                Text(relativeTimestamp)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if note.duration > 0 {
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(timeString(note.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if note.transcriptionStatus == .pending {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Processing")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                } else if note.transcriptionStatus == .failed {
                    Text("Failed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    

    
    private var transcriptText: String {
        switch note.transcriptionStatus {
        case .pending:
            return "New transcription"
        case .failed:
            return "Transcription failed - tap to retry"
        case .completed:
            // Prioritize enhanced text (post-processed result) over original text
            if let enhancedText = note.enhancedText, !enhancedText.isEmpty {
                return enhancedText
            } else if !note.text.isEmpty {
                return note.text
            } else {
                return "No audible content detected."
            }
        }
    }

    private var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: note.timestamp, relativeTo: Date())
    }

    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d", m, r)
    }
}




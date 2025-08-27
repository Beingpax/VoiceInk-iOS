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
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            HStack(spacing: 16) {
                Label(note.timestamp.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if note.duration > 0 {
                    Label(timeString(note.duration), systemImage: "play.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if note.transcriptionStatus == .pending {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.blue)
                        Text("Processing...")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                } else if note.transcriptionStatus == .failed {
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
            return "New transcription"
        case .failed:
            return "Transcription failed - tap to retry"
        case .completed:
            let displayText = note.enhancedText ?? note.text
            return displayText.isEmpty ? "No audible content detected." : displayText
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d", m, r)
    }
}




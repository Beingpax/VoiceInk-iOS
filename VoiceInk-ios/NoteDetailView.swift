import SwiftUI
import SwiftData

struct NoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let note: Transcription
    
    @State private var isRetranscribing = false
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Main content with scroll
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Transcription status and retry button
                        if note.needsTranscription {
                            transcriptionStatusView
                        }

                        // Transcript content
                        if note.transcriptionStatus == .completed {
                            transcriptContentView
                        }
                        
                        // Add bottom padding to account for audio player
                        if hasAudioFile {
                            Color.clear
                                .frame(height: 100)
                        }
                    }
                    .padding()
                }
                .scrollIndicators(.hidden)
                
                // Bottom audio player (web-form style)
                if hasAudioFile {
                    bottomAudioPlayer
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal)
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : 16)
                }
            }
        }
        .navigationTitle("Note")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
    
    private var transcriptContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transcript")
                    .font(.headline)
                Spacer()
                Button(action: { copyToClipboard(displayedTranscriptText) }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                }
            }
            
            Text(displayedTranscriptText)
                .font(.body)
                .textSelection(.enabled)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private var displayedTranscriptText: String {
        // Backend logic: Show post-processed result if available, otherwise show original
        if let enhancedText = note.enhancedText, !enhancedText.isEmpty {
            return enhancedText
        } else if !note.text.isEmpty {
            return note.text
        } else {
            return "No content available."
        }
    }
    
    private var hasAudioFile: Bool {
        guard let audioPath = note.fullAudioPath,
              FileManager.default.fileExists(atPath: audioPath) else {
            return false
        }
        return true
    }

    // Summary card removed per design feedback
    
    private var bottomAudioPlayer: some View {
        VStack(spacing: 0) {
            if let audioPath = note.fullAudioPath,
               FileManager.default.fileExists(atPath: audioPath) {
                AudioPlayerView(audioFilePath: audioPath, duration: note.duration, timestamp: note.timestamp)
            } else if note.audioFileURL != nil && !note.audioFileURL!.isEmpty {
                // Modern error state - file missing
                HStack(spacing: 12) {
                    Circle()
                        .fill(.orange.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "exclamationmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.orange)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Audio Unavailable")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text("File not found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            } else if note.duration > 0 {
                // Modern error state - path missing
                HStack(spacing: 12) {
                    Circle()
                        .fill(.orange.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "exclamationmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.orange)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Audio Unavailable")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text("Path missing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }
    
    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d", m, r)
    }
    
    private var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: note.timestamp, relativeTo: Date())
    }
    
    private var transcriptionStatusView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: note.transcriptionStatus == .failed ? "exclamationmark.triangle.fill" : "clock.fill")
                    .foregroundStyle(note.transcriptionStatus == .failed ? .red : .orange)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(note.transcriptionStatus == .failed ? "Transcription Failed" : "Transcription Pending")
                        .font(.subheadline.weight(.medium))
                    if let error = note.transcriptionError, !error.isEmpty {
                        Text(error)
                            .font(.callout)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Spacer()
            }
            
            // Mode selection for re-transcription
            if !settings.modes.isEmpty && !isRetranscribing {
                VStack(spacing: 8) {
                    if settings.modes.count > 1 {
                        Picker("Mode", selection: $settings.selectedModeId) {
                            ForEach(settings.modes) { mode in
                                Text(mode.name).tag(mode.id as UUID?)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 80)
                    } else if let singleMode = settings.modes.first {
                        Text(singleMode.name)
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                    }
                }
            }
            
            if isRetranscribing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Retranscribing...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    retranscribe()
                } label: {
                    Label("Retry Transcription", systemImage: "arrow.clockwise")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.regular)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func retranscribe() {
        isRetranscribing = true
        
        Task {
            defer { isRetranscribing = false }
            
            do {
                _ = try await TranscriptionRetryService.shared.retranscribe(note: note)
                try? modelContext.save() // Save the updated note
            } catch {
                // Error handling is already done in the service
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        
        // Optional: Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    

}



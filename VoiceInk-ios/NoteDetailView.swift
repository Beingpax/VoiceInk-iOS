import SwiftUI
import SwiftData

struct NoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let note: Note
    
    @State private var isRetranscribing = false
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Main content with scroll
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        // Transcription status and retry button
                        if note.needsTranscription {
                            transcriptionStatusView
                        }

                        // Transcript content (moved to top)
                        if note.transcriptionStatus == .completed {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Transcript")
                                    .font(.headline)
                                
                                Text(note.transcript.isEmpty ? "No content" : note.transcript)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .padding()
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        
                        // Add bottom padding to account for audio player
                        if hasAudioFile {
                            Color.clear
                                .frame(height: 100)
                        }
                    }
                    .padding()
                }
                
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
    }
    
    private var hasAudioFile: Bool {
        guard let audioPath = note.fullAudioPath,
              FileManager.default.fileExists(atPath: audioPath) else {
            return false
        }
        return true
    }
    
    private var bottomAudioPlayer: some View {
        VStack(spacing: 0) {
            if let audioPath = note.fullAudioPath,
               FileManager.default.fileExists(atPath: audioPath) {
                AudioPlayerView(audioFilePath: audioPath, duration: note.durationSeconds)
            } else if note.audioFilePath != nil && !note.audioFilePath!.isEmpty {
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
            } else if note.durationSeconds > 0 {
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
    
    private var transcriptionStatusView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: note.transcriptionStatus == .failed ? "exclamationmark.triangle.fill" : "clock.fill")
                    .foregroundStyle(note.transcriptionStatus == .failed ? .red : .orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.transcriptionStatus == .failed ? "Transcription Failed" : "Transcription Pending")
                        .font(.subheadline.weight(.medium))
                    
                    if let error = note.transcriptionError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Mode selection for re-transcription
            if !settings.modes.isEmpty && !isRetranscribing {
                VStack(spacing: 8) {
                    HStack {
                        Text("Transcription Mode")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    
                    if settings.modes.count > 1 {
                        Picker("Mode", selection: $settings.selectedModeId) {
                            ForEach(settings.modes) { mode in
                                Text(mode.name).tag(mode.id as UUID?)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else if let singleMode = settings.modes.first {
                        Text(singleMode.name)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                Button("Retry Transcription") {
                    retranscribe()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
}



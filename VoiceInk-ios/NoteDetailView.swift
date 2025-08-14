import SwiftUI

struct NoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let note: Note
    
    @State private var isRetranscribing = false
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(note.title.isEmpty ? "New note" : note.title)
                    .font(.title2.weight(.semibold))
                Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // Audio player (only show if audio file exists)
                if let audioPath = note.audioFilePath,
                   !audioPath.isEmpty,
                   FileManager.default.fileExists(atPath: audioPath) {
                    AudioPlayerView(audioFilePath: audioPath, duration: note.durationSeconds)
                }

                // Transcription status and retry button (below audio player)
                if note.needsTranscription {
                    transcriptionStatusView
                }

                // Transcript content
                if note.transcriptionStatus == .completed {
                    Text(note.transcript.isEmpty ? "No content" : note.transcript)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
            .padding()
        }
        .navigationTitle("Note")
        .navigationBarTitleDisplayMode(.inline)
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
            } catch {
                // Error handling is already done in the service
            }
        }
    }
}



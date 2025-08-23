import SwiftUI

enum RecordingState {
    case recording
    case processing
    case completed(String)
    case error(String)
}

struct RecordSheetView: View {
    @ObservedObject var recorder: AudioRecorder
    let onStopAndTranscribe: (@escaping (Result<String, Error>, Transcription?) -> Void) -> Void
    let onDismiss: (() -> Void)? // Callback for dismissal
    @State private var animate = false
    @StateObject private var settings = AppSettings.shared
    @State private var recordingState: RecordingState = .recording
    @State private var createdNote: Transcription? // Track the note created from this recording
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            switch recordingState {
            case .recording:
                recordingView
            case .processing:
                processingView
            case .completed(let transcript):
                completedView(transcript: transcript)
            case .error(let message):
                errorView(message: message)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .interactiveDismissDisabled(recorder.isRecording)
        .presentationDetents([.large])
        .presentationBackground(Color(.systemBackground))
        .onAppear {
            animate = true
            if !recorder.isRecording { try? recorder.startRecording() }
        }
    }

    private var recordingView: some View {
        VStack(spacing: 0) {
            // Top section with status indicator
            VStack(spacing: 24) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .scaleEffect(animate ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animate)
                    Text("Recording")
                        .font(.headline)
                }
                
                // Timer
                Text(timeString(recorder.currentDuration))
                    .font(.system(.largeTitle, design: .rounded).weight(.medium))
                    .monospacedDigit()
                
                // Mode selection
                if !settings.modes.isEmpty {
                    if settings.modes.count > 1 {
                        Picker("Mode", selection: $settings.selectedModeId) {
                            ForEach(settings.modes) { mode in
                                Text(mode.name)
                                    .font(.system(.title3, design: .rounded, weight: .medium))
                                    .tag(mode.id as UUID?)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 100)
                        .onAppear {
                            // Auto-select first mode if none is selected
                            if settings.selectedModeId == nil {
                                settings.selectedModeId = settings.modes.first?.id
                            }
                        }
                    } else if let singleMode = settings.modes.first {
                        Text(singleMode.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .onAppear {
                                settings.selectedModeId = singleMode.id
                            }
                    }
                }
            }
            .padding(.top, 20)
            
            Spacer()
            
            // Bottom section with visualizer and stop button
            VStack(spacing: 24) {
                // Audio visualizer
                AudioVisualizerView(levels: recorder.levelsHistory)
                    .frame(height: 80)
                
                // Stop button
                Button(action: {
                    recordingState = .processing
                    onStopAndTranscribe { result, transcription in
                        createdNote = transcription
                        setTranscriptionResult(result)
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16, weight: .medium))
                        Text("Stop Recording")
                            .font(.headline.weight(.medium))
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                
                // Cancel button
                Button(action: {
                    recorder.stopRecording()
                    onDismiss?() ?? dismiss()
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                        Text("Cancel Recording")
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray5))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 40)
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.blue)
                
                VStack(spacing: 8) {
                    Text("Processing...")
                        .font(.title2.weight(.semibold))
                    
                    Text("Transcribing your recording")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
        }
    }
    
    private func completedView(transcript: String) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Transcript")
                    .font(.title2.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
            
            // Transcript content
            ScrollView {
                Text(transcript)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 20)
            }
            
            // Bottom actions
            VStack(spacing: 12) {
                Button(action: {
                    UIPasteboard.general.string = transcript
                    onDismiss?() ?? dismiss()
                }) {
                    Text("Copy Transcript")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    onDismiss?() ?? dismiss()
                }) {
                    Text("Done")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                
                Text("Network Error")
                    .font(.title2.weight(.semibold))
                
                Text("Recording saved! You can retry transcription later from your notes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            VStack(spacing: 12) {
                Button("Done") {
                    onDismiss?() ?? dismiss()
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Button(action: {
                    if let transcription = createdNote {
                        // Retry transcription of the created note
                        recordingState = .processing
                        Task {
                            do {
                                let transcript = try await TranscriptionRetryService.shared.retranscribe(note: transcription)
                                await MainActor.run {
                                    setTranscriptionResult(.success(transcript))
                                }
                            } catch {
                                await MainActor.run {
                                    transcription.transcriptionStatus = .failed
                                    transcription.transcriptionError = error.localizedDescription
                                    setTranscriptionResult(.failure(error))
                                }
                            }
                        }
                    } else {
                        // Start new recording (fallback)
                        recordingState = .recording
                        animate = true
                        try? recorder.startRecording()
                    }
                }) {
                    Text("Try Again")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d", m, r)
    }
    
    func setTranscriptionResult(_ result: Result<String, Error>) {
        switch result {
        case .success(let transcript):
            recordingState = .completed(transcript)
        case .failure(let error):
            recordingState = .error(error.localizedDescription)
        }
    }
}



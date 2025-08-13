import SwiftUI

enum RecordingState {
    case recording
    case processing
    case completed(String)
    case error(String)
}

struct RecordSheetView: View {
    @ObservedObject var recorder: AudioRecorder
    let onStopAndTranscribe: (@escaping (Result<String, Error>) -> Void) -> Void
    @State private var animate = false
    @StateObject private var settings = AppSettings.shared
    @State private var recordingState: RecordingState = .recording
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
        .presentationDetents([.fraction(0.45), .medium])
        .presentationBackground(Color(.systemBackground))
        .onAppear {
            animate = true
            if !recorder.isRecording { try? recorder.startRecording() }
        }
    }

    private var recordingView: some View {
        VStack(spacing: 20) {
            // Status row with dot and stop button
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .scaleEffect(animate ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animate)
                    Text("Recording")
                        .font(.headline)
                }
                
                Spacer()
                
                Button(action: {
                    recordingState = .processing
                    onStopAndTranscribe { result in
                        setTranscriptionResult(result)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text("Stop")
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            // Timer
            Text(timeString(recorder.currentDuration))
                .font(.system(.largeTitle, design: .rounded).weight(.medium))
                .monospacedDigit()

            // Audio visualizer
            AudioVisualizerView(levels: recorder.levelsHistory)
                .frame(height: 60)

            // Mode selection (positioned below visualizer)
            if !settings.modes.isEmpty {
                VStack(spacing: 8) {
                    if settings.modes.count > 1 {
                        Picker("Mode", selection: $settings.selectedModeId) {
                            ForEach(settings.modes) { mode in
                                Text(mode.name).tag(mode.id as UUID?)
                            }
                        }
                        .pickerStyle(.segmented)
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
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 16)
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
                Button("Copy Transcript") {
                    UIPasteboard.general.string = transcript
                    dismiss()
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                Button("Done") {
                    dismiss()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
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
                    dismiss()
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Button("Try Again") {
                    recordingState = .recording
                    animate = true
                    try? recorder.startRecording()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.blue)
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

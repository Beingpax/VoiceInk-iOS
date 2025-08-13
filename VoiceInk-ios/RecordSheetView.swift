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
        VStack(spacing: 16) {
            // Mode selection (only show if modes exist)
            if !settings.modes.isEmpty {
                ModeSelectionView()
                    .padding(.horizontal)
            }
            
            // Status row with dot and rectangular stop
            HStack(alignment: .center) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animate ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animate)
                Text("Recording")
                    .font(.headline)
                Spacer()
                Button(action: {
                    recordingState = .processing
                    onStopAndTranscribe { result in
                        setTranscriptionResult(result)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Text(timeString(recorder.currentDuration))
                .font(.system(.title2, design: .rounded))
                .monospacedDigit()

            AudioVisualizerView(levels: recorder.levelsHistory)
                .padding(.top, 4)

            Spacer(minLength: 8)
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text("Processing...")
                    .font(.headline)
                
                Text("Transcribing your recording")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func completedView(transcript: String) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Transcript")
                    .font(.headline)
                Spacer()
                Button("Copy") {
                    UIPasteboard.general.string = transcript
                    dismiss()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.blue)
            }
            
            ScrollView {
                Text(transcript)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Button("Done") {
                dismiss()
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                
                Text("Transcription Failed")
                    .font(.headline)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Try Again") {
                recordingState = .recording
                animate = true
                try? recorder.startRecording()
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
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

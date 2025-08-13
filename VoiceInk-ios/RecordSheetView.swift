import SwiftUI

struct RecordSheetView: View {
    @ObservedObject var recorder: AudioRecorder
    let onStopAndTranscribe: () -> Void
    @State private var animate = false

    var body: some View {
        VStack(spacing: 16) {
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
                Button(action: onStopAndTranscribe) {
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

    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d", m, r)
    }
}

#Preview {
    RecordSheetView(recorder: AudioRecorder(), onStopAndTranscribe: {})
}



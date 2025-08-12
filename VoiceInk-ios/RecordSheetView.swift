import SwiftUI

struct RecordSheetView: View {
    @ObservedObject var recorder: AudioRecorder
    let onStopAndTranscribe: () -> Void
    @State private var animate = false

    var body: some View {
        VStack(spacing: 24) {
            Capsule().fill(Color.secondary.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 8)
            Spacer(minLength: 8)
            Text(recorder.isRecording ? "Recording" : "Ready to Record")
                .font(.title2.weight(.semibold))
            Text(timeString(recorder.currentDuration))
                .font(.system(.title, design: .rounded))
                .monospacedDigit()

            ZStack {
                Circle()
                    .fill(Color.red.opacity(animate ? 0.3 : 0.15))
                    .frame(width: 220, height: 220)
                Button(action: recorder.isRecording ? onStopAndTranscribe : start) {
                    Image(systemName: recorder.isRecording ? "stop.fill" : "record.circle")
                        .foregroundStyle(.white)
                        .font(.system(size: 56))
                        .padding(40)
                        .background(recorder.isRecording ? Color.red : Color.accentColor)
                        .clipShape(Circle())
                }
            }
            .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { animate = true } }

            Spacer()
        }
        .padding()
        .presentationDetents([.fraction(0.45), .medium])
        .presentationDragIndicator(.visible)
    }

    private func start() { try? recorder.startRecording() }

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



import SwiftUI

struct RecordingView: View {
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var settings = AppSettings.shared
    @State private var isRecording = false
    @State private var animate = false
    @State private var showingNoModesAlert = false
    
    let onRecordingComplete: (URL, TimeInterval) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Simple recording button
            Button(action: toggleRecording) {
                HStack(spacing: 8) {
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    Text(isRecording ? "Stop Recording" : "Start Recording")
                        .font(.headline)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(isRecording ? .red : .accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Simple recording indicator when active
            if isRecording {
                HStack(spacing: 12) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animate ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animate)
                    
                    Text("Recording")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(timeString(recorder.currentDuration))
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .monospacedDigit()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
        .alert("No Modes Found", isPresented: $showingNoModesAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please create a new mode in Settings before recording.")
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        // Check if modes are available
        if settings.modes.isEmpty {
            showingNoModesAlert = true
            return
        }
        
        do {
            try recorder.startRecording()
            isRecording = true
            animate = true
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    private func stopRecording() {
        recorder.stopRecording()
        isRecording = false
        animate = false
        
        if let url = recorder.currentRecordingURL {
            onRecordingComplete(url, recorder.currentDuration)
        }
    }
    
    private func timeString(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    RecordingView { url, duration in
        print("Recording completed: \(url), duration: \(duration)")
    }
}

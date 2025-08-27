import SwiftUI

struct RecordingSheetView: View {
    @ObservedObject var recordingManager: RecordingManager
    @ObservedObject var settings: AppSettings
    let onCancel: () -> Void
    let onStop: () -> Void
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Text(timeString(recordingManager.currentDuration))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            
            Spacer()

            // Mode Picker
            Text("Mode")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if settings.modes.count > 1 {
                Picker("Mode", selection: $settings.selectedModeId) {
                    ForEach(settings.modes) { mode in
                        Text(mode.name).tag(mode.id as UUID?)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 100)
            } else if let singleMode = settings.modes.first {
                Text(singleMode.name)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            // Stop Button
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 70, height: 70)
                    .background(Color.red, in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d", m, r)
    }
}

#Preview {
    RecordingSheetView(
        recordingManager: RecordingManager(),
        settings: AppSettings.shared,
        onCancel: {},
        onStop: {}
    )
}

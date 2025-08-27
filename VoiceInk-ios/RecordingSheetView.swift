import SwiftUI

struct RecordingSheetView: View {
    @ObservedObject var recordingManager: RecordingManager
    @ObservedObject var settings: AppSettings
    let onCancel: () -> Void
    let onStop: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Button("Cancel", action: onCancel)
                    .font(.body)
                Spacer()
                Text(timeString(recordingManager.currentDuration))
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            .padding(.top, 8)

            // Mode Picker
            VStack(spacing: 8) {
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
                    .frame(height: 80)
                } else if let singleMode = settings.modes.first {
                    Text(singleMode.name)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                }
            }
            
            // Stop Button - Matching main button style
            Button(action: onStop) {
                Label("Stop Recording", systemImage: "stop.fill")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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

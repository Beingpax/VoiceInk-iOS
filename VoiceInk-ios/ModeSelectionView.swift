import SwiftUI

struct ModeSelectionView: View {
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            Picker("Recording Mode", selection: $settings.selectedModeId) {
                ForEach(settings.modes) { mode in
                    Text(mode.name).tag(mode.id as UUID?)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
            .onAppear {
                // Auto-select first mode if none is selected
                if settings.selectedModeId == nil && !settings.modes.isEmpty {
                    settings.selectedModeId = settings.modes.first?.id
                }
            }
            
            if let selectedMode = settings.selectedMode {
                HStack(spacing: 12) {
                    Label(selectedMode.transcriptionProvider.rawValue, systemImage: "waveform")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Label(selectedMode.postProcessingProvider.rawValue, systemImage: "brain.head.profile")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ModeSelectionView()
        .padding()
}
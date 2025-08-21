import SwiftUI

struct ModesView: View {
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if settings.modes.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(settings.modes) { mode in
                            NavigationLink(destination: ModeConfigurationView(
                                mode: mode,
                                settings: settings
                            ) { updatedMode in
                                if let index = settings.modes.firstIndex(where: { $0.id == mode.id }) {
                                    settings.modes[index] = updatedMode
                                }
                            }) {
                                ModeRowView(mode: mode)
                            }
                        }
                        .onDelete(perform: deleteMode)
                    }
                    .listStyle(.insetGrouped)
                }
                
                Spacer()
                
                // Bottom action area
                VStack(spacing: 16) {
                    NavigationLink(destination: ModeConfigurationView(
                        settings: settings
                    ) { newMode in
                        settings.modes.append(newMode)
                    }) {
                        HStack {
                            Image(systemName: "plus")
                                .font(.headline)
                            Text("New Mode")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    
                    if !settings.modes.isEmpty {
                        NavigationLink("Cloud Models") {
                            APIKeysView()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Modes")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "waveform.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 8) {
                    Text("No Modes Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Create custom recording modes with specific transcription and post-processing settings")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
        }
    }
    
    private func deleteMode(at offsets: IndexSet) {
        settings.modes.remove(atOffsets: offsets)
    }
}

struct ModeRowView: View {
    let mode: Mode
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(mode.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transcription: \(mode.transcriptionModel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if mode.isPostProcessingEnabled {
                        Text("Post-processing: \(mode.postProcessingModel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ModesView()
}
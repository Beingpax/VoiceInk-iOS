import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        List {
            Section(header: Text("Modes")) {
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
                
                NavigationLink(destination: ModeConfigurationView(
                    settings: settings
                ) { newMode in
                    settings.modes.append(newMode)
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Add New Mode")
                            .foregroundStyle(.blue)
                    }
                }
            }
            
            Section(header: Text("Local Models")) {
                NavigationLink(destination: LocalModelManagementView()) {
                    Text("Manage Local Models")
                }
            }
            
            Section(header: Text("API Keys")) {
                ForEach(Provider.allCases.filter { $0 != .local }) { provider in
                    NavigationLink(destination: ProviderAPIKeyView(provider: provider)) {
                        HStack {
                            Text(provider.rawValue)
                            Spacer()
                            if !settings.apiKey(for: provider).isEmpty {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
    
    private func deleteMode(at offsets: IndexSet) {
        settings.modes.remove(atOffsets: offsets)
    }
}



#Preview {
    NavigationStack { SettingsView() }
}



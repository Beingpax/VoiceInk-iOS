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
            
            Section(header: Text("Cloud Models")) {
                NavigationLink(destination: APIKeysView()) {
                    Text("Manage Cloud Models")
                }
            }
            
            #if DEBUG
            Section(header: Text("Development")) {
                Button("Reset Onboarding") {
                    UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                    // Force app restart to show onboarding
                    exit(0)
                }
                .foregroundColor(.red)
            }
            #endif
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



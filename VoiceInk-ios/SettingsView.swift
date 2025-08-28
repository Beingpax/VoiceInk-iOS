import SwiftUI
import SwiftData

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
            
            Section(header: Text("Audio Settings")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Session Timeout")
                        Spacer()
                        Text("\(settings.audioSessionTimeoutSeconds)s")
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(settings.audioSessionTimeoutSeconds) },
                            set: { settings.audioSessionTimeoutSeconds = Int($0) }
                        ),
                        in: 0...300,
                        step: 15
                    )
                    
                    Text("How long to keep the microphone session active after recording stops. Longer timeouts prevent 'session activation failed' errors when recording frequently, but may use more battery.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }

            #if DEBUG
            Section(header: Text("Debug")) {
                Button(role: .destructive) {
                    resetAppData()
                } label: {
                    Label("Reset All App Data", systemImage: "trash")
                }
            }
            #endif
        }
        .navigationTitle("Settings")
    }
    
    private func deleteMode(at offsets: IndexSet) {
        settings.modes.remove(atOffsets: offsets)
    }

    #if DEBUG
    private func resetAppData() {
        // 1) Delete all SwiftData Transcription records
        do {
            let descriptor = FetchDescriptor<Transcription>()
            let modelContainer = try ModelContainer(for: Transcription.self)
            let context = ModelContext(modelContainer)
            let notes = try context.fetch(descriptor)
            for note in notes {
                context.delete(note)
            }
            try? context.save()
        } catch {
            print("Failed to reset SwiftData: \(error)")
        }

        // 2) Delete audio files directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsURL.appendingPathComponent("Recordings")
        if FileManager.default.fileExists(atPath: recordingsDir.path) {
            try? FileManager.default.removeItem(at: recordingsDir)
        }

        // 3) Delete local model directory
        let modelsDir = LocalModelManager.modelsDirectory
        if FileManager.default.fileExists(atPath: modelsDir.path) {
            try? FileManager.default.removeItem(at: modelsDir)
        }

        // 4) Clear caches and tmp contents (best-effort)
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        if let cacheItems = try? FileManager.default.contentsOfDirectory(at: cachesURL, includingPropertiesForKeys: nil) {
            for url in cacheItems { try? FileManager.default.removeItem(at: url) }
        }
        let tmpPath = NSTemporaryDirectory()
        if let tmpItems = try? FileManager.default.contentsOfDirectory(atPath: tmpPath) {
            for item in tmpItems { try? FileManager.default.removeItem(atPath: (tmpPath as NSString).appendingPathComponent(item)) }
        }

        // 5) Reset settings, modes, and keys
        settings.resetAll()
    }
    #endif
}



#Preview {
    NavigationStack { SettingsView() }
}



import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @State private var tempKey: String = ""
    @State private var isVerifying: Bool = false
    @State private var verifyResult: Bool? = nil

    private let service = GroqTranscriptionService()

    var body: some View {
        Form {
            Section(header: Text("OpenAI-compatible API"), footer: Text("Currently uses Groq's OpenAI-compatible endpoints. Your key is stored securely in UserDefaults on-device.")) {
                SecureField("API Key", text: $tempKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                HStack {
                    Button(action: saveKey) {
                        Label("Save", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(tempKey.isEmpty)
                    Spacer()
                    if isVerifying {
                        ProgressView().progressViewStyle(.circular)
                    } else {
                        Button(action: verifyKey) {
                            Label("Verify", systemImage: "checkmark.seal")
                        }
                        .disabled(settings.openAICompatibleAPIKey.isEmpty)
                    }
                }
                if let verifyResult {
                    Label(verifyResult ? "Key verified" : "Verification failed", systemImage: verifyResult ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(verifyResult ? .green : .red)
                }
            }

            Section(header: Text("Model")) {
                TextField("Preferred model", text: $settings.preferredModel)
            }
        }
        .navigationTitle("Settings")
        .onAppear { tempKey = settings.openAICompatibleAPIKey }
    }

    private func saveKey() {
        settings.openAICompatibleAPIKey = tempKey
    }

    private func verifyKey() {
        Task {
            isVerifying = true
            let ok = await service.verifyAPIKey(settings.openAICompatibleAPIKey)
            verifyResult = ok
            isVerifying = false
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
}



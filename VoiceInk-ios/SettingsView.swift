import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @State private var tempKey: String = ""
    @State private var isVerifying: Bool = false
    @State private var verifyResult: Bool? = nil

    private let service = GroqTranscriptionService()

    var body: some View {
        Form {
            Section(header: Text("Provider")) {
                Picker("Provider", selection: $settings.selectedProvider) {
                    ForEach(Provider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("API Key")) {
                SecureField("\(settings.selectedProvider.rawValue) API Key", text: $tempKey)
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
                        .disabled(currentAPIKey().isEmpty)
                    }
                }
                if let verifyResult {
                    Label(verifyResult ? "Key verified" : "Verification failed", systemImage: verifyResult ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(verifyResult ? .green : .red)
                }
            }

            Section(header: Text("Model")) {
                Picker("Model", selection: $settings.preferredModel) {
                    ForEach(settings.selectedProvider.availableModels, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
            }

            Section(header: Text("Post-processing"), footer: Text("Optionally improve your transcript automatically using the selected LLM and prompt.")) {
                Picker("LLM Provider", selection: $settings.llmProvider) {
                    ForEach(Provider.allCases) { p in Text(p.rawValue).tag(p) }
                }
                Picker("LLM Model", selection: $settings.llmModel) {
                    ForEach(settings.llmProvider.availableLLMModels, id: \.self) { m in Text(m).tag(m) }
                }
                TextField("Custom prompt (optional)", text: $settings.postProcessPrompt, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
        }
        .navigationTitle("Settings")
        .onAppear { tempKey = currentAPIKey() }
        .onChange(of: settings.selectedProvider) { _, _ in
            tempKey = currentAPIKey()
            verifyResult = nil
        }
    }

    private func currentAPIKey() -> String {
        settings.apiKey(for: settings.selectedProvider)
    }

    private func saveKey() {
        settings.setAPIKey(tempKey, for: settings.selectedProvider)
    }

    private func verifyKey() {
        Task {
            isVerifying = true
            let ok = await service.verifyAPIKey(apiBaseURL: settings.selectedProvider.baseURL, currentAPIKey())
            verifyResult = ok
            isVerifying = false
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
}



import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @State private var tempKey: String = ""
    @State private var isVerifying: Bool = false
    @State private var verifyResult: Bool? = nil
    @State private var editingKey: Bool = true

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
                if editingKey {
                    SecureField("\(settings.selectedProvider.rawValue) API Key", text: $tempKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    HStack {
                        Button(action: saveKey) {
                            Label("Save", systemImage: "checkmark.circle.fill")
                        }
                        .disabled(tempKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Spacer()
                        if isVerifying {
                            ProgressView().progressViewStyle(.circular)
                        } else {
                            Button(action: verifyKey) {
                                Label("Verify", systemImage: "checkmark.seal")
                            }
                            .disabled(tempKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && currentAPIKey().isEmpty)
                        }
                    }
                } else {
                    HStack {
                        Label("Key verified", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                        Spacer()
                        Button("Change") {
                            editingKey = true
                            verifyResult = nil
                            tempKey = currentAPIKey()
                        }
                    }
                    if let existing = obfuscatedKey() {
                        Text(existing).font(.caption).foregroundStyle(.secondary)
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
        .onAppear {
            tempKey = currentAPIKey()
            editingKey = currentAPIKey().isEmpty ? true : (verifyResult != true)
        }
        .onChange(of: settings.selectedProvider) { _, _ in
            tempKey = currentAPIKey()
            verifyResult = nil
            editingKey = currentAPIKey().isEmpty
        }
        .onChange(of: tempKey) { _, _ in
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
            let entered = tempKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let keyToVerify = entered.isEmpty ? currentAPIKey() : entered
            let ok = await service.verifyAPIKey(apiBaseURL: settings.selectedProvider.baseURL, keyToVerify)
            verifyResult = ok
            isVerifying = false
            if ok {
                // Auto-save verified key and switch to non-editing state
                if !entered.isEmpty { settings.setAPIKey(entered, for: settings.selectedProvider) }
                editingKey = false
            }
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
}



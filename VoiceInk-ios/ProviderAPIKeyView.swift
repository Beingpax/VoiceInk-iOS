import SwiftUI

struct ProviderAPIKeyView: View {
    let provider: Provider
    @StateObject private var settings = AppSettings.shared
    @State private var tempKey: String = ""
    @State private var isVerifying: Bool = false
    @State private var verifyResult: Bool? = nil
    @State private var editingKey: Bool = true

    private let groqService = GroqTranscriptionService()
    private let deepgramService = DeepgramTranscriptionService()
    private let openAIClient = OpenAICompatibleClient()
    
    private var isKeyVerified: Bool {
        settings.isKeyVerified(for: provider)
    }

    var body: some View {
        Form {
            Section(header: Text("\(provider.rawValue) API Key")) {
                if editingKey {
                    SecureField("\(provider.rawValue) API Key", text: $tempKey)
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
                            settings.setKeyVerified(false, for: provider)
                        }
                    }
                    if let existing = obfuscatedKey() {
                        Text(existing).font(.caption).foregroundStyle(.secondary)
                    }
                }

                // Only show verification result when actively verifying and not already verified
                if let verifyResult = verifyResult, !isKeyVerified {
                    Label(verifyResult ? "Key verified" : "Verification failed", systemImage: verifyResult ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(verifyResult ? .green : .red)
                }
            }
            
            Section(header: Text("Get API Key")) {
                Link(destination: provider.consoleURL) {
                    HStack {
                        Image(systemName: "link")
                        Text("\(provider.rawValue) API Console")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(provider.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            tempKey = currentAPIKey()
            editingKey = !isKeyVerified
            verifyResult = nil
        }
        .onChange(of: tempKey) { _, _ in
            verifyResult = nil
        }
    }

    private func currentAPIKey() -> String {
        settings.apiKey(for: provider)
    }

    private func saveKey() {
        settings.setAPIKey(tempKey, for: provider)
    }

    private func verifyKey() {
        Task {
            isVerifying = true
            let entered = tempKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let keyToVerify = entered.isEmpty ? currentAPIKey() : entered
            
            let ok: Bool
            switch provider {
            case .deepgram:
                ok = await deepgramService.verifyAPIKey(apiBaseURL: provider.baseURL, keyToVerify)
            case .gemini, .openai, .cerebras:
                ok = await openAIClient.verifyAPIKey(baseURL: provider.baseURL, apiKey: keyToVerify)
            default:
                ok = await groqService.verifyAPIKey(apiBaseURL: provider.baseURL, keyToVerify)
            }
            
            verifyResult = ok
            isVerifying = false
            if ok {
                if !entered.isEmpty { settings.setAPIKey(entered, for: provider) }
                settings.setKeyVerified(true, for: provider)
                editingKey = false
            }
        }
    }

    private func obfuscatedKey() -> String? {
        let key = currentAPIKey().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        let count = key.count
        if count <= 6 { return String(repeating: "•", count: count) }
        let prefixCount = min(4, count)
        let suffixCount = min(4, max(0, count - prefixCount))
        let start = key.prefix(prefixCount)
        let end = key.suffix(suffixCount)
        let middleCount = max(4, count - prefixCount - suffixCount)
        return "\(start)\(String(repeating: "•", count: middleCount))\(end)"
    }
}

#Preview {
    NavigationStack { ProviderAPIKeyView(provider: .groq) }
}
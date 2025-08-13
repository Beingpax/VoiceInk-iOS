import SwiftUI

struct APIKeysView: View {
    @StateObject private var settings = AppSettings.shared
    @State private var tempGroqKey: String = ""
    @State private var tempOpenAIKey: String = ""
    @State private var isVerifyingGroq: Bool = false
    @State private var isVerifyingOpenAI: Bool = false
    @State private var groqVerifyResult: Bool? = nil
    @State private var openAIVerifyResult: Bool? = nil
    @State private var editingGroq: Bool = true
    @State private var editingOpenAI: Bool = true

    private let service = GroqTranscriptionService()

    var body: some View {
        Form {
            Section(header: Text("Groq API Key")) {
                if editingGroq {
                    SecureField("Groq API Key", text: $tempGroqKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    HStack {
                        Button(action: { saveKey(for: .groq) }) {
                            Label("Save", systemImage: "checkmark.circle.fill")
                        }
                        .disabled(tempGroqKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Spacer()
                        if isVerifyingGroq {
                            ProgressView().progressViewStyle(.circular)
                        } else {
                            Button(action: { verifyKey(for: .groq) }) {
                                Label("Verify", systemImage: "checkmark.seal")
                            }
                            .disabled(tempGroqKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && settings.groqAPIKey.isEmpty)
                        }
                    }
                } else {
                    HStack {
                        Label("Key verified", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                        Spacer()
                        Button("Change") {
                            editingGroq = true
                            groqVerifyResult = nil
                            tempGroqKey = settings.groqAPIKey
                        }
                    }
                    if let existing = obfuscatedKey(settings.groqAPIKey) {
                        Text(existing).font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let verifyResult = groqVerifyResult {
                    Label(verifyResult ? "Key verified" : "Verification failed", systemImage: verifyResult ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(verifyResult ? .green : .red)
                }
            }
            
            Section(header: Text("OpenAI API Key")) {
                if editingOpenAI {
                    SecureField("OpenAI API Key", text: $tempOpenAIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    HStack {
                        Button(action: { saveKey(for: .openai) }) {
                            Label("Save", systemImage: "checkmark.circle.fill")
                        }
                        .disabled(tempOpenAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Spacer()
                        if isVerifyingOpenAI {
                            ProgressView().progressViewStyle(.circular)
                        } else {
                            Button(action: { verifyKey(for: .openai) }) {
                                Label("Verify", systemImage: "checkmark.seal")
                            }
                            .disabled(tempOpenAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && settings.openAIAPIKey.isEmpty)
                        }
                    }
                } else {
                    HStack {
                        Label("Key verified", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                        Spacer()
                        Button("Change") {
                            editingOpenAI = true
                            openAIVerifyResult = nil
                            tempOpenAIKey = settings.openAIAPIKey
                        }
                    }
                    if let existing = obfuscatedKey(settings.openAIAPIKey) {
                        Text(existing).font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let verifyResult = openAIVerifyResult {
                    Label(verifyResult ? "Key verified" : "Verification failed", systemImage: verifyResult ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(verifyResult ? .green : .red)
                }
            }
        }
        .navigationTitle("API Keys")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            tempGroqKey = settings.groqAPIKey
            tempOpenAIKey = settings.openAIAPIKey
            editingGroq = settings.groqAPIKey.isEmpty ? true : (groqVerifyResult != true)
            editingOpenAI = settings.openAIAPIKey.isEmpty ? true : (openAIVerifyResult != true)
        }
        .onChange(of: tempGroqKey) { _, _ in
            groqVerifyResult = nil
        }
        .onChange(of: tempOpenAIKey) { _, _ in
            openAIVerifyResult = nil
        }
    }

    private func saveKey(for provider: Provider) {
        switch provider {
        case .groq:
            settings.groqAPIKey = tempGroqKey
        case .openai:
            settings.openAIAPIKey = tempOpenAIKey
        }
    }

    private func verifyKey(for provider: Provider) {
        Task {
            switch provider {
            case .groq:
                isVerifyingGroq = true
                let entered = tempGroqKey.trimmingCharacters(in: .whitespacesAndNewlines)
                let keyToVerify = entered.isEmpty ? settings.groqAPIKey : entered
                let ok = await service.verifyAPIKey(apiBaseURL: provider.baseURL, keyToVerify)
                groqVerifyResult = ok
                isVerifyingGroq = false
                if ok {
                    if !entered.isEmpty { settings.groqAPIKey = entered }
                    editingGroq = false
                }
            case .openai:
                isVerifyingOpenAI = true
                let entered = tempOpenAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
                let keyToVerify = entered.isEmpty ? settings.openAIAPIKey : entered
                let ok = await service.verifyAPIKey(apiBaseURL: provider.baseURL, keyToVerify)
                openAIVerifyResult = ok
                isVerifyingOpenAI = false
                if ok {
                    if !entered.isEmpty { settings.openAIAPIKey = entered }
                    editingOpenAI = false
                }
            }
        }
    }

    private func obfuscatedKey(_ key: String) -> String? {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let count = trimmed.count
        if count <= 6 { return String(repeating: "•", count: count) }
        let prefixCount = min(4, count)
        let suffixCount = min(4, max(0, count - prefixCount))
        let start = trimmed.prefix(prefixCount)
        let end = trimmed.suffix(suffixCount)
        let middleCount = max(4, count - prefixCount - suffixCount)
        return "\(start)\(String(repeating: "•", count: middleCount))\(end)"
    }
}

#Preview {
    NavigationStack { APIKeysView() }
}
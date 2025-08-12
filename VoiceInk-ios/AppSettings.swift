import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Provider selection and model
    @Published var selectedProvider: Provider {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedProvider")
            ensurePreferredModelIsValid()
        }
    }

    @Published var preferredModel: String {
        didSet { UserDefaults.standard.set(preferredModel, forKey: "preferredModel") }
    }

    // Post-processing LLM provider and model
    @Published var llmProvider: Provider {
        didSet {
            UserDefaults.standard.set(llmProvider.rawValue, forKey: "llmProvider")
            ensureLLMModelIsValid()
        }
    }

    @Published var llmModel: String {
        didSet { UserDefaults.standard.set(llmModel, forKey: "llmModel") }
    }

    @Published var postProcessPrompt: String {
        didSet { UserDefaults.standard.set(postProcessPrompt, forKey: "postProcessPrompt") }
    }

    // Separate API keys per provider
    @Published var groqAPIKey: String {
        didSet { UserDefaults.standard.set(groqAPIKey, forKey: "groqAPIKey") }
    }

    @Published var openAIAPIKey: String {
        didSet { UserDefaults.standard.set(openAIAPIKey, forKey: "openAIAPIKey") }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "selectedProvider"), let p = Provider(rawValue: raw) {
            self.selectedProvider = p
        } else {
            self.selectedProvider = .groq
        }
        self.preferredModel = UserDefaults.standard.string(forKey: "preferredModel") ?? Provider.groq.availableModels.first ?? "whisper-large-v3"
        if let raw = UserDefaults.standard.string(forKey: "llmProvider"), let p = Provider(rawValue: raw) {
            self.llmProvider = p
        } else {
            self.llmProvider = .groq
        }
        let initialLLMModel = UserDefaults.standard.string(forKey: "llmModel") ?? self.llmProvider.availableLLMModels.first ?? "llama-3.1-8b-instant"
        self.llmModel = initialLLMModel
        self.postProcessPrompt = UserDefaults.standard.string(forKey: "postProcessPrompt") ?? ""
        self.groqAPIKey = UserDefaults.standard.string(forKey: "groqAPIKey") ?? ""
        self.openAIAPIKey = UserDefaults.standard.string(forKey: "openAIAPIKey") ?? ""
        ensurePreferredModelIsValid()
        ensureLLMModelIsValid()
    }

    func apiKey(for provider: Provider) -> String {
        switch provider { case .groq: return groqAPIKey; case .openai: return openAIAPIKey }
    }

    func setAPIKey(_ key: String, for provider: Provider) {
        switch provider { case .groq: groqAPIKey = key; case .openai: openAIAPIKey = key }
    }

    private func ensurePreferredModelIsValid() {
        if !selectedProvider.availableModels.contains(preferredModel) {
            preferredModel = selectedProvider.availableModels.first ?? preferredModel
        }
    }

    private func ensureLLMModelIsValid() {
        if !llmProvider.availableLLMModels.contains(llmModel) {
            llmModel = llmProvider.availableLLMModels.first ?? llmModel
        }
    }
}



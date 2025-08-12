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
        self.groqAPIKey = UserDefaults.standard.string(forKey: "groqAPIKey") ?? ""
        self.openAIAPIKey = UserDefaults.standard.string(forKey: "openAIAPIKey") ?? ""
        ensurePreferredModelIsValid()
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
}



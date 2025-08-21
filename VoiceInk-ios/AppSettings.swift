import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Modes system
    @Published var modes: [Mode] {
        didSet { saveModes() }
    }
    
    @Published var selectedModeId: UUID? {
        didSet { 
            if let id = selectedModeId {
                UserDefaults.standard.set(id.uuidString, forKey: "selectedModeId")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedModeId")
            }
        }
    }
    
    var selectedMode: Mode? {
        guard let selectedModeId = selectedModeId else { return nil }
        return modes.first { $0.id == selectedModeId }
    }

    // Legacy properties for backward compatibility (deprecated)
    @Published var selectedProvider: Provider {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedProvider")
            ensurePreferredModelIsValid()
        }
    }

    @Published var preferredModel: String {
        didSet { UserDefaults.standard.set(preferredModel, forKey: "preferredModel") }
    }

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

    @Published var deepgramAPIKey: String {
        didSet { UserDefaults.standard.set(deepgramAPIKey, forKey: "deepgramAPIKey") }
    }

    @Published var cerebrasAPIKey: String {
        didSet { UserDefaults.standard.set(cerebrasAPIKey, forKey: "cerebrasAPIKey") }
    }

    @Published var geminiAPIKey: String {
        didSet { UserDefaults.standard.set(geminiAPIKey, forKey: "geminiAPIKey") }
    }
    
    // Track verification status per provider
    @Published var groqKeyVerified: Bool {
        didSet { UserDefaults.standard.set(groqKeyVerified, forKey: "groqKeyVerified") }
    }
    
    @Published var openAIKeyVerified: Bool {
        didSet { UserDefaults.standard.set(openAIKeyVerified, forKey: "openAIKeyVerified") }
    }

    @Published var deepgramKeyVerified: Bool {
        didSet { UserDefaults.standard.set(deepgramKeyVerified, forKey: "deepgramKeyVerified") }
    }

    @Published var cerebrasKeyVerified: Bool {
        didSet { UserDefaults.standard.set(cerebrasKeyVerified, forKey: "cerebrasKeyVerified") }
    }

    @Published var geminiKeyVerified: Bool {
        didSet { UserDefaults.standard.set(geminiKeyVerified, forKey: "geminiKeyVerified") }
    }
    


    private init() {
        // Load modes
        self.modes = Self.loadModes()
        
        // Load selected mode
        if let selectedModeIdString = UserDefaults.standard.string(forKey: "selectedModeId"),
           let selectedModeId = UUID(uuidString: selectedModeIdString) {
            self.selectedModeId = selectedModeId
        } else {
            self.selectedModeId = nil
        }
        
        // Legacy settings for backward compatibility
        if let raw = UserDefaults.standard.string(forKey: "selectedProvider"), let p = Provider(rawValue: raw) {
            self.selectedProvider = p
        } else {
            self.selectedProvider = .groq
        }
        self.preferredModel = UserDefaults.standard.string(forKey: "preferredModel") ?? Provider.groq.models(for: .transcription).first ?? "whisper-large-v3"
        let storedLLMProviderRaw = UserDefaults.standard.string(forKey: "llmProvider")
        let resolvedLLMProvider = Provider(rawValue: storedLLMProviderRaw ?? "") ?? .groq
        self.llmProvider = resolvedLLMProvider
        let initialLLMModel = UserDefaults.standard.string(forKey: "llmModel") ?? resolvedLLMProvider.models(for: .postProcessing).first ?? "llama-3.1-8b-instant"
        self.llmModel = initialLLMModel
        self.postProcessPrompt = UserDefaults.standard.string(forKey: "postProcessPrompt") ?? ""
        self.groqAPIKey = UserDefaults.standard.string(forKey: "groqAPIKey") ?? ""
        self.openAIAPIKey = UserDefaults.standard.string(forKey: "openAIAPIKey") ?? ""
        self.deepgramAPIKey = UserDefaults.standard.string(forKey: "deepgramAPIKey") ?? ""
        self.cerebrasAPIKey = UserDefaults.standard.string(forKey: "cerebrasAPIKey") ?? ""
        self.geminiAPIKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        self.groqKeyVerified = UserDefaults.standard.bool(forKey: "groqKeyVerified")
        self.openAIKeyVerified = UserDefaults.standard.bool(forKey: "openAIKeyVerified")
        self.deepgramKeyVerified = UserDefaults.standard.bool(forKey: "deepgramKeyVerified")
        self.cerebrasKeyVerified = UserDefaults.standard.bool(forKey: "cerebrasKeyVerified")
        self.geminiKeyVerified = UserDefaults.standard.bool(forKey: "geminiKeyVerified")
        ensurePreferredModelIsValid()
        ensureLLMModelIsValid()
    }

    func apiKey(for provider: Provider) -> String {
        switch provider { 
        case .groq: return groqAPIKey
        case .openai: return openAIAPIKey
        case .deepgram: return deepgramAPIKey
        case .cerebras: return cerebrasAPIKey
        case .gemini: return geminiAPIKey
        case .local: return "local" // Local transcription doesn't need an API key
        }
    }

    func setAPIKey(_ key: String, for provider: Provider) {
        switch provider { 
        case .groq: 
            groqAPIKey = key
            // Reset verification status when key changes
            if groqAPIKey != key { groqKeyVerified = false }
        case .openai: 
            openAIAPIKey = key
            // Reset verification status when key changes
            if openAIAPIKey != key { openAIKeyVerified = false }
        case .deepgram:
            deepgramAPIKey = key
            // Reset verification status when key changes
            if deepgramAPIKey != key { deepgramKeyVerified = false }
        case .cerebras:
            cerebrasAPIKey = key
            // Reset verification status when key changes
            if cerebrasAPIKey != key { cerebrasKeyVerified = false }
        case .gemini:
            geminiAPIKey = key
            // Reset verification status when key changes
            if geminiAPIKey != key { geminiKeyVerified = false }
        case .local:
            break // Local provider doesn't use API keys
        }
    }
    
    func isKeyVerified(for provider: Provider) -> Bool {
        switch provider {
        case .groq: return groqKeyVerified && !groqAPIKey.isEmpty
        case .openai: return openAIKeyVerified && !openAIAPIKey.isEmpty
        case .deepgram: return deepgramKeyVerified && !deepgramAPIKey.isEmpty
        case .cerebras: return cerebrasKeyVerified && !cerebrasAPIKey.isEmpty
        case .gemini: return geminiKeyVerified && !geminiAPIKey.isEmpty
        case .local: return LocalModelManager.shared.hasAvailableModel
        }
    }
    
    func setKeyVerified(_ verified: Bool, for provider: Provider) {
        switch provider {
        case .groq: groqKeyVerified = verified
        case .openai: openAIKeyVerified = verified
        case .deepgram: deepgramKeyVerified = verified
        case .cerebras: cerebrasKeyVerified = verified
        case .gemini: geminiKeyVerified = verified
        case .local: break // Local model status is handled by LocalModelManager
        }
    }

    private func ensurePreferredModelIsValid() {
        let availableModels = selectedProvider.models(for: .transcription)
        if !availableModels.contains(preferredModel) {
            preferredModel = availableModels.first ?? preferredModel
        }
    }

    private func ensureLLMModelIsValid() {
        let availableModels = llmProvider.models(for: .postProcessing)
        if !availableModels.contains(llmModel) {
            llmModel = availableModels.first ?? llmModel
        }
    }
    

    
    // MARK: - Modes Management
    
    private func saveModes() {
        if let data = try? JSONEncoder().encode(modes) {
            UserDefaults.standard.set(data, forKey: "modes")
        }
    }
    
    private static func loadModes() -> [Mode] {
        guard let data = UserDefaults.standard.data(forKey: "modes"),
              let modes = try? JSONDecoder().decode([Mode].self, from: data) else {
            return []
        }
        return modes
    }
    
    // MARK: - Mode-based Settings
    
    /// Get the effective transcription provider (from selected mode, first mode, or fallback to legacy)
    var effectiveTranscriptionProvider: Provider {
        if let selectedMode = selectedMode {
            return selectedMode.transcriptionProvider
        } else if let firstMode = modes.first {
            return firstMode.transcriptionProvider
        } else {
            return selectedProvider
        }
    }
    
    /// Get the effective transcription model (from selected mode, first mode, or fallback to legacy)
    var effectiveTranscriptionModel: String {
        if let selectedMode = selectedMode {
            return selectedMode.transcriptionModel
        } else if let firstMode = modes.first {
            return firstMode.transcriptionModel
        } else {
            return preferredModel
        }
    }
    
    /// Get the effective post-processing provider (from selected mode, first mode, or fallback to legacy)
    var effectivePostProcessingProvider: Provider {
        if let selectedMode = selectedMode {
            return selectedMode.postProcessingProvider
        } else if let firstMode = modes.first {
            return firstMode.postProcessingProvider
        } else {
            return llmProvider
        }
    }
    
    /// Get the effective post-processing model (from selected mode, first mode, or fallback to legacy)
    var effectivePostProcessingModel: String {
        if let selectedMode = selectedMode {
            return selectedMode.postProcessingModel
        } else if let firstMode = modes.first {
            return firstMode.postProcessingModel
        } else {
            return llmModel
        }
    }
    
    /// Get the effective custom prompt (from selected mode, first mode, or fallback to legacy)
    var effectiveCustomPrompt: String {
        if let selectedMode = selectedMode {
            return selectedMode.customPrompt
        } else if let firstMode = modes.first {
            return firstMode.customPrompt
        } else {
            return postProcessPrompt
        }
    }
}



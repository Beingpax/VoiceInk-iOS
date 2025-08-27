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



    // Separate API keys per provider
    @Published var groqAPIKey: String {
        didSet { saveAPIKey(groqAPIKey, forKey: "groqAPIKey") }
    }

    @Published var openAIAPIKey: String {
        didSet { saveAPIKey(openAIAPIKey, forKey: "openAIAPIKey") }
    }

    @Published var deepgramAPIKey: String {
        didSet { saveAPIKey(deepgramAPIKey, forKey: "deepgramAPIKey") }
    }

    @Published var cerebrasAPIKey: String {
        didSet { saveAPIKey(cerebrasAPIKey, forKey: "cerebrasAPIKey") }
    }

    @Published var geminiAPIKey: String {
        didSet { saveAPIKey(geminiAPIKey, forKey: "geminiAPIKey") }
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
        

        self.groqAPIKey = AppSettings.loadAPIKey(forKey: "groqAPIKey")
        self.openAIAPIKey = AppSettings.loadAPIKey(forKey: "openAIAPIKey")
        self.deepgramAPIKey = AppSettings.loadAPIKey(forKey: "deepgramAPIKey")
        self.cerebrasAPIKey = AppSettings.loadAPIKey(forKey: "cerebrasAPIKey")
        self.geminiAPIKey = AppSettings.loadAPIKey(forKey: "geminiAPIKey")
        self.groqKeyVerified = UserDefaults.standard.bool(forKey: "groqKeyVerified")
        self.openAIKeyVerified = UserDefaults.standard.bool(forKey: "openAIKeyVerified")
        self.deepgramKeyVerified = UserDefaults.standard.bool(forKey: "deepgramKeyVerified")
        self.cerebrasKeyVerified = UserDefaults.standard.bool(forKey: "cerebrasKeyVerified")
        self.geminiKeyVerified = UserDefaults.standard.bool(forKey: "geminiKeyVerified")

    }

    func apiKey(for provider: Provider) -> String {
        switch provider { 
        case .groq: return groqAPIKey
        case .openai: return openAIAPIKey
        case .deepgram: return deepgramAPIKey
        case .cerebras: return cerebrasAPIKey
        case .gemini: return geminiAPIKey
        case .local: return "local" // Local transcription doesn't need an API key
        case .voiceink: return "" // TODO: Replace with actual VoiceInk API key
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
        case .voiceink:
            break // VoiceInk uses hardcoded API key
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
        case .voiceink: return true // VoiceInk uses hardcoded API key, always verified
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
        case .voiceink: break // VoiceInk uses hardcoded API key, no verification needed
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
    
    /// Get the effective transcription provider (from selected mode or first mode)
    var effectiveTranscriptionProvider: Provider {
        if let selectedMode = selectedMode {
            return selectedMode.transcriptionProvider
        } else if let firstMode = modes.first {
            return firstMode.transcriptionProvider
        } else {
            return .groq // Default fallback
        }
    }
    
    /// Get the effective transcription model (from selected mode or first mode)
    var effectiveTranscriptionModel: String {
        if let selectedMode = selectedMode {
            return selectedMode.transcriptionProvider == .voiceink ? voiceInkTranscriptionModel() : selectedMode.transcriptionModel
        } else if let firstMode = modes.first {
            return firstMode.transcriptionProvider == .voiceink ? voiceInkTranscriptionModel() : firstMode.transcriptionModel
        } else {
            return effectiveTranscriptionProvider == .voiceink ? voiceInkTranscriptionModel() : "whisper-large-v3" // Default fallback
        }
    }
    
    /// Get the effective post-processing provider (from selected mode or first mode)
    var effectivePostProcessingProvider: Provider {
        if let selectedMode = selectedMode {
            return selectedMode.postProcessingProvider
        } else if let firstMode = modes.first {
            return firstMode.postProcessingProvider
        } else {
            return .groq // Default fallback
        }
    }
    
    /// Get the effective post-processing model (from selected mode or first mode)
    var effectivePostProcessingModel: String {
        if let selectedMode = selectedMode {
            return selectedMode.postProcessingProvider == .voiceink ? voiceInkPostProcessingModel() : selectedMode.postProcessingModel
        } else if let firstMode = modes.first {
            return firstMode.postProcessingProvider == .voiceink ? voiceInkPostProcessingModel() : firstMode.postProcessingModel
        } else {
            return effectivePostProcessingProvider == .voiceink ? voiceInkPostProcessingModel() : "llama-3.1-8b-instant" // Default fallback
        }
    }
    
    /// Get the effective custom prompt (from selected mode or first mode)
    var effectiveCustomPrompt: String {
        if let selectedMode = selectedMode {
            return selectedMode.customPrompt
        } else if let firstMode = modes.first {
            return firstMode.customPrompt
        } else {
            return "" // Default fallback
        }
    }
    
    /// Get whether post-processing is enabled (from selected mode or first mode)
    var effectiveIsPostProcessingEnabled: Bool {
        if let selectedMode = selectedMode {
            return selectedMode.isPostProcessingEnabled
        } else if let firstMode = modes.first {
            return firstMode.isPostProcessingEnabled
        } else {
            return false // Default fallback
        }
    }
    
    // MARK: - VoiceInk Hardcoded Models
    
    /// Get the hardcoded transcription model for VoiceInk
    func voiceInkTranscriptionModel() -> String {
        return "whisper-large-v3"
    }
    
    /// Get the hardcoded post-processing model for VoiceInk
    func voiceInkPostProcessingModel() -> String {
        return "openai/gpt-oss-120b"
    }

    private func saveAPIKey(_ key: String, forKey account: String) {
        guard let data = key.data(using: .utf8) else { return }
        let status = KeychainService.save(key: account, data: data)
        if status != errSecSuccess {
            print("Error saving API key to keychain: \(status)")
        }
    }
    
    private static func loadAPIKey(forKey account: String) -> String {
        if let data = KeychainService.load(key: account), let key = String(data: data, encoding: .utf8) {
            return key
        }
        return ""
    }
}



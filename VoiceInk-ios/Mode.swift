import Foundation

struct Mode: Identifiable, Codable {
    let id: UUID
    var name: String
    
    // Transcription settings
    var transcriptionProvider: Provider
    var transcriptionModel: String
    
    // Post-processing settings
    var isPostProcessingEnabled: Bool
    var postProcessingProvider: Provider
    var postProcessingModel: String
    var promptTemplate: PromptTemplate
    
    init(name: String, 
         transcriptionProvider: Provider = .groq,
         transcriptionModel: String? = nil,
         isPostProcessingEnabled: Bool = false,
         postProcessingProvider: Provider = .groq,
         postProcessingModel: String? = nil,
         promptTemplate: PromptTemplate? = nil) {
        self.id = UUID()
        self.name = name
        self.transcriptionProvider = transcriptionProvider
        self.transcriptionModel = transcriptionModel ?? transcriptionProvider.models(for: .transcription).first ?? "whisper-large-v3"
        self.isPostProcessingEnabled = isPostProcessingEnabled
        self.postProcessingProvider = postProcessingProvider
        self.postProcessingModel = postProcessingModel ?? postProcessingProvider.models(for: .postProcessing).first ?? "llama-3.1-8b-instant"
        self.promptTemplate = promptTemplate ?? PromptTemplate(type: .summary)
    }
    
    /// Legacy support for custom prompts - creates a custom template
    @available(*, deprecated, message: "Use promptTemplate instead")
    var customPrompt: String {
        get {
            return promptTemplate.type == .custom ? promptTemplate.customPrompt : ""
        }
        set {
            if !newValue.isEmpty {
                promptTemplate = PromptTemplate(type: .custom, customPrompt: newValue)
            }
        }
    }
    
    /// Returns the effective prompt to use for post-processing
    var effectivePrompt: String {
        return promptTemplate.effectivePrompt
    }
}
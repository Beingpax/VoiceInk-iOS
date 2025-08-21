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
    var customPrompt: String
    
    init(name: String, 
         transcriptionProvider: Provider = .groq,
         transcriptionModel: String? = nil,
         isPostProcessingEnabled: Bool = false,
         postProcessingProvider: Provider = .groq,
         postProcessingModel: String? = nil,
         customPrompt: String = "") {
        self.id = UUID()
        self.name = name
        self.transcriptionProvider = transcriptionProvider
        self.transcriptionModel = transcriptionModel ?? transcriptionProvider.models(for: .transcription).first ?? "whisper-large-v3"
        self.isPostProcessingEnabled = isPostProcessingEnabled
        self.postProcessingProvider = postProcessingProvider
        self.postProcessingModel = postProcessingModel ?? postProcessingProvider.models(for: .postProcessing).first ?? "llama-3.1-8b-instant"
        self.customPrompt = customPrompt
    }
}
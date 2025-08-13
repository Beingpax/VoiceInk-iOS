import Foundation

struct Mode: Identifiable, Codable {
    let id: UUID
    var name: String
    
    // Transcription settings
    var transcriptionProvider: Provider
    var transcriptionModel: String
    
    // Post-processing settings
    var postProcessingProvider: Provider
    var postProcessingModel: String
    var customPrompt: String
    
    init(name: String, 
         transcriptionProvider: Provider = .groq,
         transcriptionModel: String = "whisper-large-v3",
         postProcessingProvider: Provider = .groq,
         postProcessingModel: String = "llama-3.1-8b-instant",
         customPrompt: String = "") {
        self.id = UUID()
        self.name = name
        self.transcriptionProvider = transcriptionProvider
        self.transcriptionModel = transcriptionModel
        self.postProcessingProvider = postProcessingProvider
        self.postProcessingModel = postProcessingModel
        self.customPrompt = customPrompt
    }
}
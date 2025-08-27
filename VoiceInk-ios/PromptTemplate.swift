import Foundation

enum PromptTemplateType: String, CaseIterable, Codable {
    case custom = "Custom"
    case summary = "Summary"
    case keyPoints = "Key Points"
    case rewrite = "Rewrite"
    case transcriptCleanup = "Clean Transcript"
    
    var displayName: String {
        return self.rawValue
    }
    
    var prompt: String {
        switch self {
        case .custom:
            return "" // Custom prompts are handled separately
        case .summary:
            return "Please provide a concise summary of the following transcription, capturing the main points and key information in a clear and organized manner:"
        case .keyPoints:
            return "Please extract the key points from the following transcription and present them as a bulleted list, highlighting the most important information:"
        case .rewrite:
            return "Please rewrite the following transcription to improve clarity, grammar, and flow while preserving the original meaning and intent:"
        case .transcriptCleanup:
            return "Please clean up the following transcription by correcting any errors, removing filler words, and improving readability while maintaining the speaker's original meaning and tone:"
        }
    }
}

struct PromptTemplate: Identifiable, Codable {
    let id = UUID()
    let type: PromptTemplateType
    let customPrompt: String // Only used when type is .custom
    
    init(type: PromptTemplateType, customPrompt: String = "") {
        self.type = type
        self.customPrompt = customPrompt
    }
    
    /// Returns the effective prompt to use for post-processing
    var effectivePrompt: String {
        switch type {
        case .custom:
            return customPrompt
        default:
            return type.prompt
        }
    }
    
    /// Returns a display-friendly description of the template
    var description: String {
        switch type {
        case .custom:
            return customPrompt.isEmpty ? "Custom prompt (empty)" : "Custom: \(customPrompt.prefix(50))..."
        default:
            return type.displayName
        }
    }
}

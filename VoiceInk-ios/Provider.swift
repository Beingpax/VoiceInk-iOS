import Foundation

enum ModelType {
    case transcription
    case postProcessing
}

enum Provider: String, CaseIterable, Codable, Identifiable {
    case groq = "Groq"
    case openai = "OpenAI"
    case deepgram = "Deepgram"
    case cerebras = "Cerebras"
    case gemini = "Gemini"
    case local = "Local (Whisper)"

    var id: String { rawValue }

    var baseURL: URL {
        switch self {
        case .groq: return URL(string: "https://api.groq.com/openai")!
        case .openai: return URL(string: "https://api.openai.com")!
        case .deepgram: return URL(string: "https://api.deepgram.com")!
        case .cerebras: return URL(string: "https://api.cerebras.ai")!
        case .gemini: return URL(string: "https://generativelanguage.googleapis.com/v1beta/openai")!
        case .local: return URL(string: "http://localhost")! // Not used for local transcription
        }
    }
    
    var consoleURL: URL {
        switch self {
        case .groq: return URL(string: "https://console.groq.com/keys")!
        case .openai: return URL(string: "https://platform.openai.com/api-keys")!
        case .deepgram: return URL(string: "https://console.deepgram.com/project/keys")!
        case .cerebras: return URL(string: "https://cloud.cerebras.ai/platform")!
        case .gemini: return URL(string: "https://aistudio.google.com/app/apikey")!
        case .local: return URL(string: "https://github.com/ggerganov/whisper.cpp")! // Whisper.cpp GitHub page
        }
    }

    func models(for type: ModelType) -> [String] {
        switch (self, type) {
        case (.groq, .transcription):
            return [
                "whisper-large-v3",
                "whisper-large-v3-turbo",
                "whisper-medium",
                "whisper-small"
            ]
        case (.groq, .postProcessing):
            return [
                "llama-3.1-8b-instant",
                "llama-3.1-70b-versatile"
            ]
        case (.openai, .transcription):
            return [
                "whisper-1",
                "gpt-4o-transcribe",
                "gpt-4o-mini-transcribe"
            ]
        case (.openai, .postProcessing):
            return [
                "gpt-4o-mini",
                "gpt-3.5-turbo"
            ]
        case (.deepgram, .transcription):
            return [
                "nova-2",
                "nova-3"
            ]
        case (.deepgram, .postProcessing):
            return []
        case (.cerebras, .transcription):
            return []
        case (.cerebras, .postProcessing):
            return [
                "llama3.1-8b",
                "llama3.1-70b"
            ]
        case (.gemini, .transcription):
            return []
        case (.gemini, .postProcessing):
            return [
                "gemini-2.0-flash",
                "gemini-2.5-flash",
                "gemini-1.5-flash",
                "gemini-1.5-pro"
            ]
        case (.local, .transcription):
            return [
                "base"
            ]
        case (.local, .postProcessing):
            return [] // Local transcription doesn't support post-processing
        }
    }
}



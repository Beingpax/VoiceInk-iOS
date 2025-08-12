import Foundation

enum Provider: String, CaseIterable, Codable, Identifiable {
    case groq = "Groq"
    case openai = "OpenAI"

    var id: String { rawValue }

    var baseURL: URL {
        switch self {
        case .groq: return URL(string: "https://api.groq.com/openai")!
        case .openai: return URL(string: "https://api.openai.com")!
        }
    }

    var availableModels: [String] {
        switch self {
        case .groq:
            return [
                "whisper-large-v3",
                "whisper-large-v3-turbo",
                "whisper-medium",
                "whisper-small"
            ]
        case .openai:
            return [
                "whisper-1"
            ]
        }
    }
}



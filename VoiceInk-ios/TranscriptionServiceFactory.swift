//
//  TranscriptionServiceFactory.swift
//

import Foundation

struct TranscriptionServiceFactory {
    static func service(for provider: Provider) -> TranscriptionService {
        switch provider {
        case .deepgram:
            return DeepgramTranscriptionService()
        case .groq, .openai, .cerebras, .gemini:
            return GroqTranscriptionService()
        case .local:
            return WhisperTranscriptionService()
        }
    }
}
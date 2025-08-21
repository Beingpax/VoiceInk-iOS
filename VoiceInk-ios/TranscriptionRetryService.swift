//
//  TranscriptionRetryService.swift
//  VoiceInk-ios
//
//  Created by AI Assistant on 12/08/2025.
//

import Foundation

class TranscriptionRetryService {
    private let postProcessor = LLMPostProcessor()
    
    static let shared = TranscriptionRetryService()
    
    private init() {}
    
    /// Retries transcription for a given note using current app settings
    func retranscribe(note: Note) async throws -> String {
        guard let audioPath = note.fullAudioPath,
              FileManager.default.fileExists(atPath: audioPath) else {
            throw TranscriptionError.audioFileNotFound
        }
        
        let settings = AppSettings.shared
        let provider = await settings.effectiveTranscriptionProvider
        let apiKey = await settings.apiKey(for: provider)
        let model = await settings.effectiveTranscriptionModel
        
        guard !apiKey.isEmpty else {
            throw TranscriptionError.noApiKey
        }
        
        let fileURL = URL(fileURLWithPath: audioPath)
        let transcriptionService = TranscriptionServiceFactory.service(for: provider)
        let rawText = try await transcriptionService.transcribeAudioFile(
            apiBaseURL: provider.baseURL,
            apiKey: apiKey,
            model: model,
            fileURL: fileURL,
            language: nil
        )
        
        // Clean up transcription
        let cleanedText = rawText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n\n+", with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
        
        var finalText = cleanedText
        
        // Optional post-processing
        var postProcessingError: String? = nil
        if await settings.effectiveIsPostProcessingEnabled {
            let ppPrompt = await settings.effectiveCustomPrompt
            if !ppPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let llmProvider = await settings.effectivePostProcessingProvider
                let llmKey = await settings.apiKey(for: llmProvider)
                let llmModel = await settings.effectivePostProcessingModel
                if !llmKey.isEmpty {
                    do {
                        finalText = try await postProcessor.postProcessTranscript(
                            provider: llmProvider,
                            apiKey: llmKey,
                            model: llmModel,
                            prompt: ppPrompt,
                            transcript: cleanedText
                        )
                    } catch {
                        // Post-processing failed, but transcription succeeded
                        postProcessingError = "Post-processing failed: \(error.localizedDescription)"
                        // Still use the cleaned transcription text
                        finalText = cleanedText
                    }
                }
            }
        }
        
        // Update note
        note.transcript = finalText
        note.transcriptionStatus = .completed
        note.transcriptionError = postProcessingError
        
        return finalText
    }
}

enum TranscriptionError: LocalizedError {
    case audioFileNotFound
    case noApiKey
    
    var errorDescription: String? {
        switch self {
        case .audioFileNotFound:
            return "Audio file not found"
        case .noApiKey:
            return "No API key configured"
        }
    }
}

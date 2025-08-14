//
//  TranscriptionRetryService.swift
//  VoiceInk-ios
//
//  Created by AI Assistant on 12/08/2025.
//

import Foundation

class TranscriptionRetryService {
    private let transcriptionService = GroqTranscriptionService()
    private let postProcessor = LLMPostProcessor()
    
    static let shared = TranscriptionRetryService()
    
    private init() {}
    
    /// Retries transcription for a given note using current app settings
    func retranscribe(note: Note) async throws -> String {
        guard let audioPath = note.audioFilePath,
              FileManager.default.fileExists(atPath: audioPath) else {
            throw TranscriptionError.audioFileNotFound
        }
        
        let settings = AppSettings.shared
        let provider = settings.effectiveTranscriptionProvider
        let apiKey = settings.apiKey(for: provider)
        let model = settings.effectiveTranscriptionModel
        
        guard !apiKey.isEmpty else {
            throw TranscriptionError.noApiKey
        }
        
        let fileURL = URL(fileURLWithPath: audioPath)
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
        let ppPrompt = settings.effectiveCustomPrompt
        if !ppPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let llmProvider = settings.effectivePostProcessingProvider
            let llmKey = settings.apiKey(for: llmProvider)
            let llmModel = settings.effectivePostProcessingModel
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
                    // Fall back to cleaned text
                }
            }
        }
        
        // Update note
        note.transcript = finalText
        note.transcriptionStatus = .completed
        note.transcriptionError = nil
        
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

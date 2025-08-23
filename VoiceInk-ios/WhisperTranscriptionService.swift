//
//  WhisperTranscriptionService.swift
//  VoiceInk-ios
//
//  Local transcription service using Whisper.cpp
//

import Foundation

enum WhisperTranscriptionError: Error {
    case noModelAvailable
    case modelLoadFailed
    case audioProcessingFailed
    case transcriptionFailed
    
    var localizedDescription: String {
        switch self {
        case .noModelAvailable:
            return "No local Whisper model is available. Please download a model first."
        case .modelLoadFailed:
            return "Failed to load the Whisper model."
        case .audioProcessingFailed:
            return "Failed to process audio file for transcription."
        case .transcriptionFailed:
            return "Whisper transcription failed."
        }
    }
}

struct WhisperTranscriptionService: TranscriptionService {
    
    /// Transcribe audio file using local Whisper model
    func transcribeAudioFile(
        apiBaseURL: URL,
        apiKey: String,
        model: String,
        fileURL: URL,
        language: String? = nil
    ) async throws -> String {
        
        print("WhisperTranscriptionService: Starting local transcription")
        
        // Get available model
        let modelManager = LocalModelManager.shared
        guard let modelPath = await modelManager.baseModelPath else {
            throw WhisperTranscriptionError.noModelAvailable
        }
        
        print("WhisperTranscriptionService: Using model at \(modelPath)")
        
        // Load Whisper context
        let context: WhisperContext
        do {
            context = try await WhisperContext.createContext(path: modelPath)
        } catch {
            print("WhisperTranscriptionService: Failed to load model: \(error)")
            throw WhisperTranscriptionError.modelLoadFailed
        }
        
        // Process audio file (expecting WAV format from recorder)
        let audioSamples: [Float]
        do {
            audioSamples = try decodeWaveFile(fileURL)
            print("WhisperTranscriptionService: Processed \(audioSamples.count) audio samples")
        } catch {
            print("WhisperTranscriptionService: Audio processing failed: \(error)")
            // Clean up resources before throwing
            await context.releaseResources()
            print("WhisperTranscriptionService: Whisper context resources released.")
            throw WhisperTranscriptionError.audioProcessingFailed
        }
        
        // Perform transcription
        let success = await context.fullTranscribe(samples: audioSamples)
        
        if success {
            let transcription = await context.getTranscription()
            // Clean up resources
            await context.releaseResources()
            print("WhisperTranscriptionService: Whisper context resources released.")
            print("WhisperTranscriptionService: Transcription completed successfully")
            return transcription.isEmpty ? "No audio detected." : transcription
        } else {
            // Clean up resources before throwing error
            await context.releaseResources()
            print("WhisperTranscriptionService: Whisper context resources released.")
            print("WhisperTranscriptionService: Transcription failed")
            throw WhisperTranscriptionError.transcriptionFailed
        }
    }
    
    /// Verify API key (not applicable for local transcription, always returns true if model is available)
    func verifyAPIKey(apiBaseURL: URL, _ apiKey: String) async -> Bool {
        let modelManager = LocalModelManager.shared
        return await modelManager.hasAvailableModel
    }
}

// MARK: - Convenience Extensions

extension WhisperTranscriptionService {
    
    /// Transcribe audio with simplified parameters for local use
    func transcribeAudioFile(_ fileURL: URL) async throws -> String {
        // Use dummy values for parameters that don't apply to local transcription
        return try await transcribeAudioFile(
            apiBaseURL: URL(string: "http://localhost")!,
            apiKey: "local",
            model: "base.en",
            fileURL: fileURL,
            language: "en"
        )
    }
    
    /// Check if local transcription is available
    @MainActor
    static var isAvailable: Bool {
        LocalModelManager.shared.hasAvailableModel
    }
    
    /// Get status information for UI display
    @MainActor
    static func getStatusInfo() -> (isAvailable: Bool, modelInfo: String?) {
        let modelManager = LocalModelManager.shared
        
        if let model = modelManager.firstAvailableModel {
            return (true, "\(model.displayName) (\(model.size))")
        } else {
            return (false, "No model downloaded")
        }
    }
}

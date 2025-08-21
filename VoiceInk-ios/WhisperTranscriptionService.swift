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
        guard let modelPath = modelManager.baseModelPath else {
            throw WhisperTranscriptionError.noModelAvailable
        }
        
        print("WhisperTranscriptionService: Using model at \(modelPath)")
        
        // Load Whisper context
        let whisperContext: WhisperContext
        do {
            whisperContext = try WhisperContext.createContext(path: modelPath)
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
            throw WhisperTranscriptionError.audioProcessingFailed
        }
        
        // Perform transcription
        do {
            let transcription = await whisperContext.fullTranscribe(samples: audioSamples)
            
            if transcription.isEmpty {
                print("WhisperTranscriptionService: Warning - empty transcription result")
                return "No speech detected"
            }
            
            print("WhisperTranscriptionService: Transcription completed successfully")
            return transcription
            
        } catch {
            print("WhisperTranscriptionService: Transcription failed: \(error)")
            throw WhisperTranscriptionError.transcriptionFailed
        }
    }
    
    /// Verify API key (not applicable for local transcription, always returns true if model is available)
    func verifyAPIKey(apiBaseURL: URL, _ apiKey: String) async -> Bool {
        let modelManager = LocalModelManager.shared
        return modelManager.hasAvailableModel
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
    static var isAvailable: Bool {
        LocalModelManager.shared.hasAvailableModel
    }
    
    /// Get status information for UI display
    static func getStatusInfo() -> (isAvailable: Bool, modelInfo: String?) {
        let modelManager = LocalModelManager.shared
        
        if let model = modelManager.firstAvailableModel {
            return (true, "\(model.displayName) (\(model.size))")
        } else {
            return (false, "No model downloaded")
        }
    }
}

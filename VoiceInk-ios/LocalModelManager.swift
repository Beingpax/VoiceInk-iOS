//
//  LocalModelManager.swift
//  VoiceInk-ios
//
//  Manages local Whisper model downloading and storage
//

import Foundation
import Combine

enum ModelDownloadError: Error {
    case invalidURL
    case downloadFailed
    case fileSystemError
}

struct WhisperModel: Identifiable, Codable {
    let id = UUID()
    let name: String
    let displayName: String
    let downloadURL: String
    let filename: String
    let size: String
    let description: String
    
    var fileURL: URL {
        LocalModelManager.modelsDirectory.appendingPathComponent(filename)
    }
    
    var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    // Base model for initial implementation
    static let baseModel = WhisperModel(
        name: "base",
        displayName: "Whisper Base Model",
        downloadURL: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin",
        filename: "ggml-base.bin",
        size: "142 MB",
        description: "Multilingual model with good balance of speed and accuracy"
    )
    
    // Future models can be added here
    static let availableModels = [baseModel]
}

@MainActor
class LocalModelManager: ObservableObject {
    @Published var downloadProgress: [UUID: Double] = [:]
    @Published var isDownloading: [UUID: Bool] = [:]
    @Published var downloadError: String?
    
    private var downloadTasks: [UUID: URLSessionDownloadTask] = [:]
    private var progressObservations: [UUID: NSKeyValueObservation] = [:]
    
    static let shared = LocalModelManager()
    
    nonisolated static var modelsDirectory: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = documentsDir.appendingPathComponent("WhisperModels")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: modelsDir.path) {
            try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        }
        
        return modelsDir
    }
    
    private init() {
        setupModelsDirectory()
    }
    
    private func setupModelsDirectory() {
        let _ = Self.modelsDirectory // This will create the directory
    }
    
    /// Download a specific model
    func downloadModel(_ model: WhisperModel) async throws {
        guard !isDownloading[model.id, default: false] else {
            print("LocalModelManager: Model \(model.name) is already being downloaded")
            return
        }
        
        guard let url = URL(string: model.downloadURL) else {
            throw ModelDownloadError.invalidURL
        }
        
        print("LocalModelManager: Starting download of \(model.name) from \(model.downloadURL)")
        
        isDownloading[model.id] = true
        downloadProgress[model.id] = 0.0
        downloadError = nil
        
        do {
            let downloadTask = URLSession.shared.downloadTask(with: url) { [weak self] temporaryURL, response, error in
                Task { @MainActor in
                    self?.handleDownloadCompletion(
                        for: model,
                        temporaryURL: temporaryURL,
                        response: response,
                        error: error
                    )
                }
            }
            
            // Track progress
            let progressObservation = downloadTask.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                Task { @MainActor in
                    self?.downloadProgress[model.id] = progress.fractionCompleted
                }
            }
            
            downloadTasks[model.id] = downloadTask
            progressObservations[model.id] = progressObservation
            downloadTask.resume()
            
        } catch {
            isDownloading[model.id] = false
            downloadError = "Download failed: \(error.localizedDescription)"
            throw ModelDownloadError.downloadFailed
        }
    }
    
    private func handleDownloadCompletion(
        for model: WhisperModel,
        temporaryURL: URL?,
        response: URLResponse?,
        error: Error?
    ) {
        defer {
            isDownloading[model.id] = false
            downloadTasks[model.id] = nil
            progressObservations[model.id] = nil
            downloadProgress[model.id] = nil
        }
        
        if let error = error {
            downloadError = "Download failed: \(error.localizedDescription)"
            print("LocalModelManager: Download failed for \(model.name): \(error)")
            return
        }
        
        guard let response = response as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else {
            downloadError = "Server error during download"
            print("LocalModelManager: Server error for \(model.name)")
            return
        }
        
        guard let temporaryURL = temporaryURL else {
            downloadError = "No file received"
            print("LocalModelManager: No file received for \(model.name)")
            return
        }
        
        do {
            // Move file to final location
            let finalURL = model.fileURL
            
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: finalURL.path) {
                try FileManager.default.removeItem(at: finalURL)
            }
            
            try FileManager.default.moveItem(at: temporaryURL, to: finalURL)
            
            print("LocalModelManager: Successfully downloaded \(model.name) to \(finalURL.path)")
            downloadProgress[model.id] = 1.0
            
        } catch {
            downloadError = "Failed to save model: \(error.localizedDescription)"
            print("LocalModelManager: Failed to save \(model.name): \(error)")
        }
    }
    
    /// Cancel download for a specific model
    func cancelDownload(for model: WhisperModel) {
        downloadTasks[model.id]?.cancel()
        downloadTasks[model.id] = nil
        progressObservations[model.id] = nil
        isDownloading[model.id] = false
        downloadProgress[model.id] = nil
    }
    
    /// Delete a downloaded model
    func deleteModel(_ model: WhisperModel) throws {
        guard model.isDownloaded else { 
            print("LocalModelManager: Model \(model.name) is not downloaded")
            return 
        }
        
        do {
            try FileManager.default.removeItem(at: model.fileURL)
            print("LocalModelManager: Successfully deleted model \(model.name)")
            
            // Trigger UI update
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        } catch {
            print("LocalModelManager: Failed to delete model \(model.name): \(error)")
            throw error
        }
    }
    
    /// Get the path to the downloaded base model, if available
    var baseModelPath: String? {
        let model = WhisperModel.baseModel
        return model.isDownloaded ? model.fileURL.path : nil
    }
    
    /// Check if any model is available for transcription
    var hasAvailableModel: Bool {
        WhisperModel.availableModels.contains { $0.isDownloaded }
    }
    
    /// Get the first available model for transcription
    var firstAvailableModel: WhisperModel? {
        WhisperModel.availableModels.first { $0.isDownloaded }
    }
    
    /// Get disk usage information for models
    func getModelsDiskUsage() -> (totalSize: Int64, modelCount: Int) {
        let modelsDir = Self.modelsDirectory
        var totalSize: Int64 = 0
        var modelCount = 0
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: modelsDir, includingPropertiesForKeys: [.fileSizeKey])
            
            for fileURL in contents {
                if fileURL.pathExtension == "bin" {
                    modelCount += 1
                    if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                       let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            }
        } catch {
            print("LocalModelManager: Error calculating disk usage: \(error)")
        }
        
        return (totalSize, modelCount)
    }
}

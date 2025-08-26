//
//  LocalModelManagementView.swift
//  VoiceInk-ios
//
//  UI for managing local Whisper models
//

import SwiftUI
import Combine

struct LocalModelManagementView: View {
    @StateObject private var modelManager = LocalModelManager.shared
    @State private var showingDownloadAlert = false
    @State private var selectedModel: WhisperModel?
    
    var body: some View {
        List {
            ForEach(WhisperModel.availableModels) { model in
                ModelRowView(model: model, modelManager: modelManager)
            }
        }
        .navigationTitle("Local Models")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            // Refresh model status
            modelManager.objectWillChange.send()
        }
        .alert("Download Error", isPresented: .constant(modelManager.downloadError != nil)) {
            Button("OK") {
                modelManager.downloadError = nil
            }
        } message: {
            if let error = modelManager.downloadError {
                Text(error)
            }
        }
    }
    

}

struct ModelRowView: View {
    let model: WhisperModel
    @ObservedObject var modelManager: LocalModelManager
    @State private var showingDeleteAlert = false
    @State private var showingDownloadConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.headline)
                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Action button where size used to be
                if model.isDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                } else if modelManager.isDownloading[model.id] == true {
                    Button(action: {
                        modelManager.cancelDownload(for: model)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                    }
                } else {
                    Button(action: {
                        showingDownloadConfirmation = true
                    }) {
                        Image(systemName: "icloud.and.arrow.down")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                }
            }
            
            // Progress indicator when downloading
            if modelManager.isDownloading[model.id] == true {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Downloading...")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                        Text("\(Int((modelManager.downloadProgress[model.id] ?? 0) * 100))%")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: modelManager.downloadProgress[model.id] ?? 0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if model.isDownloaded {
                Button("Delete") {
                    showingDeleteAlert = true
                }
                .tint(.red)
            }
        }
        .alert("Delete Model", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteModel()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Delete \(model.displayName)? This will remove the model from your device.")
        }
        .alert("Download Model", isPresented: $showingDownloadConfirmation) {
            Button("Download") {
                downloadModel()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To enable offline transcription, a \(model.size) model needs to be downloaded. This may incur data charges if you are not on Wi-Fi.")
        }
    }
    
    private func downloadModel() {
        Task {
            do {
                try await modelManager.downloadModel(model)
            } catch {
                print("Download failed: \(error)")
            }
        }
    }
    
    private func deleteModel() {
        do {
            try modelManager.deleteModel(model)
            // Force UI update by triggering objectWillChange
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                modelManager.objectWillChange.send()
            }
        } catch {
            print("Delete failed: \(error)")
            modelManager.downloadError = "Failed to delete model: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

#Preview {
    LocalModelManagementView()
}

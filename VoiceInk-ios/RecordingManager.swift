import SwiftUI
import SwiftData
import AVFoundation
import Combine

enum RecordingState: Equatable {
    case idle
    case recording
    case processing
    case completed(String)
    case error(String)
}

private enum MicrophonePermissionStatus {
    case granted, denied, undetermined
}

enum ActiveRecordingAlert: Identifiable {
    case permissionDenied
    case busy
    case generic(Error)
    
    var id: String {
        switch self {
        case .permissionDenied: return "permissionDenied"
        case .busy: return "busy"
        case .generic(let error): return "generic-\(error.localizedDescription)"
        }
    }
}
 
@MainActor
final class RecordingManager: ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var animate = false
    @Published var isRecordingSheetPresented = false
    @Published var activeRecordingAlert: ActiveRecordingAlert?
    @Published var currentRecordingNote: Transcription?
    @Published var currentDuration: Double = 0
    
    private let recorder = AudioRecorder()
    private let postProcessor = LLMPostProcessor()
    private let settings = AppSettings.shared
    private var durationTimer: Timer?
    
    var isRecording: Bool {
        recordingState == .recording
    }
    
    // MARK: - Recording Flow
    func startRecordingFlow() {
        switch checkPermissionStatus() {
        case .granted:
            proceedToStartRecording()
        case .denied:
            activeRecordingAlert = .permissionDenied
        case .undetermined:
            requestPermission { [weak self] granted in
                if granted {
                    self?.proceedToStartRecording()
                } else {
                    self?.activeRecordingAlert = .permissionDenied
                }
            }
        }
    }
    
    private func proceedToStartRecording() {
        recordingState = .recording
        animate = true
        
        // Auto-select first mode if none is selected
        if settings.selectedModeId == nil && !settings.modes.isEmpty {
            settings.selectedModeId = settings.modes.first?.id
        }
        
        do {
            try recorder.startRecording()
            startDurationTimer()
            isRecordingSheetPresented = true
        } catch {
            activeRecordingAlert = .generic(error)
            recordingState = .idle
            animate = false
        }
    }
    
    func stopRecording(modelContext: ModelContext) {
        // Stop recording and get file info
        recorder.stopRecording()
        stopDurationTimer()
        guard let fileURL = recorder.currentRecordingURL else { return }
        
        // Store relative path and duration
        let audioFileName = fileURL.lastPathComponent
        let recordingDuration = currentDuration
        
        // IMMEDIATELY create and insert the note with pending status
        let note = Transcription(
            text: "",
            duration: recordingDuration,
            audioFileURL: audioFileName,
            transcriptionStatus: .pending
        )
        modelContext.insert(note)
        try? modelContext.save()
        
        // Reset UI state immediately so user can continue using the app
        recordingState = .idle
        animate = false
        currentRecordingNote = note
        isRecordingSheetPresented = false
        
        // Start background transcription
        transcribeInBackground(note: note, audioFileName: audioFileName, recordingDuration: recordingDuration, modelContext: modelContext)
    }
    
    func cancelRecording() {
        recorder.discard()
        stopDurationTimer()
        recordingState = .idle
        animate = false
        isRecordingSheetPresented = false
        currentDuration = 0
    }
    
    // MARK: - Permissions
    private func checkPermissionStatus() -> MicrophonePermissionStatus {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted: return .granted
        case .denied: return .denied
        case .undetermined: return .undetermined
        @unknown default: return .undetermined
        }
    }
    
    private func requestPermission(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Duration Timer
    private func startDurationTimer() {
        currentDuration = 0
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentDuration += 0.1
            }
        }
    }
    
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
    
    // MARK: - Transcription
    private func transcribeInBackground(note: Transcription, audioFileName: String, recordingDuration: Double, modelContext: ModelContext) {
        Task {
            defer { 
                // Clean up recorder state
                recorder.currentRecordingURL = nil
                recorder.currentDuration = 0
            }
            
            let settings = AppSettings.shared
            
            // Use effective settings from selected mode
            let provider = settings.effectiveTranscriptionProvider
            let apiKey = settings.apiKey(for: provider)
            let model = settings.effectiveTranscriptionModel
            
            // If no API key, update note with error
            guard !apiKey.isEmpty else {
                await MainActor.run {
                    note.transcriptionStatus = .failed
                    note.transcriptionError = "No API key configured"
                    try? modelContext.save()
                }
                return
            }
            
            do {
                // Resolve the relative path to absolute path for transcription
                let recordingsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("Recordings")
                let fileURL = recordingsDir.appendingPathComponent(audioFileName)
                let service = TranscriptionServiceFactory.service(for: provider)
                let rawText = try await service.transcribeAudioFile(apiBaseURL: provider.baseURL, apiKey: apiKey, model: model, fileURL: fileURL, language: nil)
                
                // Clean up transcription
                let cleanedText = rawText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n\n+", with: "\n\n", options: .regularExpression)
                    .replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
                
                var finalText = cleanedText
                var enhancedText: String? = nil
                var postProcessingError: String? = nil
                
                // Optional post-processing
                if settings.effectiveIsPostProcessingEnabled {
                    let ppPrompt = settings.effectiveCustomPrompt
                    if !ppPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let llmProvider = settings.effectivePostProcessingProvider
                        let llmKey = settings.apiKey(for: llmProvider)
                        let llmModel = settings.effectivePostProcessingModel
                        if !llmKey.isEmpty {
                            do {
                                finalText = try await postProcessor.postProcessTranscript(provider: llmProvider, apiKey: llmKey, model: llmModel, prompt: ppPrompt, transcript: cleanedText)
                                enhancedText = finalText
                            } catch {
                                postProcessingError = "Post-processing failed: \(error.localizedDescription)"
                                finalText = cleanedText
                            }
                        }
                    }
                }
                
                // Update the existing note on main thread
                await MainActor.run {
                    note.text = cleanedText
                    note.enhancedText = enhancedText
                    note.transcriptionModelName = model
                    note.aiEnhancementModelName = settings.effectiveIsPostProcessingEnabled ? settings.effectivePostProcessingModel : nil
                    note.transcriptionStatus = .completed
                    note.transcriptionError = postProcessingError
                    try? modelContext.save()
                }
                
            } catch {
                // Update note with error on main thread
                await MainActor.run {
                    note.transcriptionStatus = .failed
                    note.transcriptionError = error.localizedDescription
                    try? modelContext.save()
                }
            }
        }
    }
}

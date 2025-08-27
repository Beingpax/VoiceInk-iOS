import SwiftUI
import SwiftData

enum RecordingState: Equatable {
    case idle
    case recording
    case processing
    case completed(String)
    case error(String)
}

struct StaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(1.0) // Always full opacity
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Transcription.timestamp, order: .reverse)]) private var notes: [Transcription]

    @StateObject private var recorder = AudioRecorder()
    @State private var searchText: String = ""
    @State private var showingNoModesAlert: Bool = false
    @State private var currentRecordingNote: Transcription?
    @State private var recordingState: RecordingState = .idle
    @State private var animate = false
    @StateObject private var settings = AppSettings.shared
    private let postProcessor = LLMPostProcessor()

    var filteredNotes: [Transcription] {
        notes.filter { note in
            searchText.isEmpty ||
            note.text.localizedCaseInsensitiveContains(searchText) ||
            (note.enhancedText ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    init() {}

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("VoiceInk")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: SettingsView()) { Image(systemName: "gearshape") }
                    }
                    

                }
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
                .safeAreaInset(edge: .bottom) { 
                    VStack(spacing: 0) {
                        if recordingState != .idle {
                            inlineRecordingView
                        }
                        recordBar
                    }
                }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            List {
                ForEach(filteredNotes) { note in
                    NavigationLink(destination: NoteDetailView(note: note)) {
                        NoteRowView(note: note)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(.insetGrouped)
        }
    }

    private var recordBar: some View {
        HStack {
            Button(action: {
                if AppSettings.shared.modes.isEmpty {
                    showingNoModesAlert = true
                } else {
                    switch recordingState {
                    case .idle, .completed, .error:
                        startInlineRecording()
                    case .recording:
                        stopInlineRecording()
                    case .processing:
                        break // Do nothing while processing
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: recordingButtonIcon)
                    Text(recordingButtonText)
                        .font(.headline)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.label))
                .foregroundStyle(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(StaticButtonStyle())
            .disabled(recordingState == .processing)
        }
        .padding(.horizontal)
        .padding(.bottom)
        .alert("No Modes Found", isPresented: $showingNoModesAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please create a new mode in Settings before recording.")
        }
    }

    private func stopAndTranscribe(completion: @escaping (Result<String, Error>, Transcription?) -> Void) {
        recorder.stopRecording()
        guard let fileURL = recorder.currentRecordingURL else { return }
        
        // ALWAYS preserve the audio file first, regardless of what happens next
        // Store relative path instead of absolute path for persistence across app launches
        let audioFileName = fileURL.lastPathComponent
        let recordingDuration = recorder.currentDuration
        
        transcribeAudio(audioFilePath: audioFileName, recordingDuration: recordingDuration, completion: completion)
    }
    
    private func transcribeAudio(audioFilePath: String, recordingDuration: Double, completion: @escaping (Result<String, Error>, Transcription?) -> Void) {
        
        Task {
            defer { 
                // Clean up recorder state but keep the audio file
                recorder.currentRecordingURL = nil
                recorder.currentDuration = 0
            }
            
            let settings = AppSettings.shared
            
            // Use effective settings from selected mode
            let provider = settings.effectiveTranscriptionProvider
            let apiKey = settings.apiKey(for: provider)
            let model = settings.effectiveTranscriptionModel
            
            // If no API key, save audio with pending status
            guard !apiKey.isEmpty else {
                let note = Transcription(
                    text: "",
                    duration: recordingDuration,
                    audioFileURL: audioFilePath,
                    transcriptionStatus: .pending,
                    transcriptionError: "No API key configured"
                )
                modelContext.insert(note)
                try? modelContext.save()
                completion(.failure(NSError(domain: "VoiceInk", code: 1, userInfo: [NSLocalizedDescriptionKey: "No API key configured"])), note)
                return
            }
            
            do {
                // Resolve the relative path to absolute path for transcription
                let recordingsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("Recordings")
                let fileURL = recordingsDir.appendingPathComponent(audioFilePath)
                let service = TranscriptionServiceFactory.service(for: provider)
                let rawText = try await service.transcribeAudioFile(apiBaseURL: provider.baseURL, apiKey: apiKey, model: model, fileURL: fileURL, language: nil)
                // Clean up transcription: trim whitespace and normalize line breaks
                let cleanedText = rawText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n\n+", with: "\n\n", options: .regularExpression) // Remove excessive line breaks
                    .replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression) // Normalize multiple spaces/tabs to single space
                
                var finalText = cleanedText
                var enhancedText: String? = nil
                
                // Optional post-processing using effective settings
                var postProcessingError: String? = nil
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
                                // Post-processing failed, but transcription succeeded
                                postProcessingError = "Post-processing failed: \(error.localizedDescription)"
                                // Still use the cleaned transcription text
                                finalText = cleanedText
                            }
                        }
                    }
                }
                
                let note = Transcription(
                    text: cleanedText,
                    duration: recordingDuration,
                    enhancedText: enhancedText,
                    audioFileURL: audioFilePath,
                    transcriptionModelName: model,
                    aiEnhancementModelName: settings.effectiveIsPostProcessingEnabled ? settings.effectivePostProcessingModel : nil,
                    transcriptionStatus: .completed,
                    transcriptionError: postProcessingError
                )
                modelContext.insert(note)
                try? modelContext.save()
                
                // Return success with transcript
                completion(.success(finalText), note)
            } catch {
                // Save the recording even if transcription failed
                let note = Transcription(
                    text: "",
                    duration: recordingDuration,
                    audioFileURL: audioFilePath,
                    transcriptionStatus: .failed,
                    transcriptionError: error.localizedDescription
                )
                modelContext.insert(note)
                try? modelContext.save()
                
                // Return error
                completion(.failure(error), note)
            }
        }
    }

    // MARK: - Computed Properties
    private var recordingButtonIcon: String {
        switch recordingState {
        case .idle:
            return "mic.fill"
        case .recording:
            return "stop.fill"
        case .processing:
            return "waveform"
        case .completed, .error:
            return "mic.fill"
        }
    }
    
    private var recordingButtonText: String {
        switch recordingState {
        case .idle:
            return "Start Recording"
        case .recording:
            return "Stop Recording"
        case .processing:
            return "Processing..."
        case .completed, .error:
            return "Start Recording"
        }
    }
    
    // MARK: - Inline Recording View
    private var inlineRecordingView: some View {
        VStack(spacing: 12) {
            switch recordingState {
            case .recording:
                recordingView
            case .processing:
                processingView
            case .completed(let transcript):
                completedView(transcript: transcript)
            case .error(let message):
                errorView(message: message)
            case .idle:
                EmptyView()
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private var recordingView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .scaleEffect(animate ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animate)
                Text("Recording")
                    .font(.headline)
                Spacer()
                Text(timeString(recorder.currentDuration))
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .monospacedDigit()
            }
            
            // Audio visualizer
            AudioVisualizerView(levels: recorder.levelsHistory)
                .frame(height: 60)
            
            // Mode selection (if multiple modes)
            if settings.modes.count > 1 {
                Picker("Mode", selection: $settings.selectedModeId) {
                    ForEach(settings.modes) { mode in
                        Text(mode.name)
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .tag(mode.id as UUID?)
                    }
                }
                .pickerStyle(.segmented)
            } else if let singleMode = settings.modes.first {
                Text(singleMode.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var processingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.blue)
            
            Text("Processing recording...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
    
    private func completedView(transcript: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Recording saved!")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
                Spacer()
                Button("Dismiss") {
                    recordingState = .idle
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }
            
            Text(transcript.prefix(100) + (transcript.count > 100 ? "..." : ""))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Recording saved with error")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
                Spacer()
                Button("Dismiss") {
                    recordingState = .idle
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }
            
            Text("Audio saved but transcription failed. You can retry from your notes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Recording Functions
    private func startInlineRecording() {
        recordingState = .recording
        animate = true
        
        // Auto-select first mode if none is selected
        if settings.selectedModeId == nil && !settings.modes.isEmpty {
            settings.selectedModeId = settings.modes.first?.id
        }
        
        do {
            try recorder.startRecording()
        } catch {
            recordingState = .error(error.localizedDescription)
        }
    }
    
    private func stopInlineRecording() {
        recordingState = .processing
        animate = false
        
        stopAndTranscribe { result, note in
            currentRecordingNote = note
            setTranscriptionResult(result)
        }
    }
    
    private func setTranscriptionResult(_ result: Result<String, Error>) {
        switch result {
        case .success(let transcript):
            recordingState = .completed(transcript)
            // Auto-dismiss after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if case .completed = recordingState {
                    recordingState = .idle
                }
            }
        case .failure(let error):
            recordingState = .error(error.localizedDescription)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets { modelContext.delete(filteredNotes[index]) }
        }
    }

    // Star/share removed

    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d", m, r)
    }
}

#Preview {
    NotesListView()
        .modelContainer(for: [Transcription.self])
}



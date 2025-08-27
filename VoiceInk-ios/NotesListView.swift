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
                    case .idle, .completed, .error, .processing:
                        startInlineRecording()
                    case .recording:
                        stopInlineRecording()
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
        }
        .padding(.horizontal)
        .padding(.bottom)
        .alert("No Modes Found", isPresented: $showingNoModesAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please create a new mode in Settings before recording.")
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
            case .idle, .processing, .completed, .error:
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
        // Stop recording and get file info
        recorder.stopRecording()
        guard let fileURL = recorder.currentRecordingURL else { return }
        
        // Store relative path and duration
        let audioFileName = fileURL.lastPathComponent
        let recordingDuration = recorder.currentDuration
        
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
        
        // Start background transcription
        transcribeInBackground(note: note, audioFileName: audioFileName, recordingDuration: recordingDuration)
    }
    
    private func transcribeInBackground(note: Transcription, audioFileName: String, recordingDuration: Double) {
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



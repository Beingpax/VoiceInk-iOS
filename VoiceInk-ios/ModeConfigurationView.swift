import SwiftUI

struct ModeConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: AppSettings
    
    @State private var mode: Mode
    @State private var isEditing: Bool
    @State private var selectedTemplateType: PromptTemplateType
    @State private var customPromptText: String
    
    let onSave: (Mode) -> Void
    
    init(mode: Mode? = nil, settings: AppSettings, onSave: @escaping (Mode) -> Void) {
        self.settings = settings
        self.onSave = onSave
        self.isEditing = mode != nil
        let initialMode = mode ?? Mode(name: "")
        self._mode = State(initialValue: initialMode)
        self._selectedTemplateType = State(initialValue: initialMode.promptTemplate.type)
        self._customPromptText = State(initialValue: initialMode.promptTemplate.customPrompt)
    }
    
    /// Available transcription providers (those with valid API keys or downloaded local models)
    private var availableTranscriptionProviders: [Provider] {
        Provider.allCases.filter { provider in
            // VoiceInk is always available (has hardcoded API key)
            if provider == .voiceink {
                return true
            }
            // Other providers: Must have models for transcription AND be properly configured
            return !provider.models(for: .transcription).isEmpty && settings.isKeyVerified(for: provider)
        }
    }
    
    /// Available post-processing providers (those with valid API keys)
    private var availablePostProcessingProviders: [Provider] {
        Provider.allCases.filter { provider in
            // VoiceInk is always available (has hardcoded API key)
            if provider == .voiceink {
                return true
            }
            // Other providers: Must have models for post-processing AND be properly configured
            return !provider.models(for: .postProcessing).isEmpty && settings.isKeyVerified(for: provider)
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("Mode Details")) {
                TextField("Mode Name", text: $mode.name)
                    .textInputAutocapitalization(.words)
            }
            
            Section(header: Text("Transcription")) {
                Picker("Provider", selection: $mode.transcriptionProvider) {
                    ForEach(availableTranscriptionProviders) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                
                if mode.transcriptionProvider != .voiceink {
                    Picker("Model", selection: $mode.transcriptionModel) {
                        ForEach(mode.transcriptionProvider.models(for: .transcription), id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                } else {
                    HStack {
                        Text("Model")
                        Spacer()
                        Text("whisper-large-v3")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("Post-processing"), 
                   footer: mode.isPostProcessingEnabled ? Text("Configure how the raw transcription should be processed and refined.") : nil) {
                Toggle("Enable Post-processing", isOn: $mode.isPostProcessingEnabled)
                
                if mode.isPostProcessingEnabled {
                    Picker("Provider", selection: $mode.postProcessingProvider) {
                        ForEach(availablePostProcessingProviders) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    
                    if mode.postProcessingProvider != .voiceink {
                        Picker("Model", selection: $mode.postProcessingModel) {
                            ForEach(mode.postProcessingProvider.models(for: .postProcessing), id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                    } else {
                        HStack {
                            Text("Model")
                            Spacer()
                            Text("gpt-oss-120b")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Prompt Template Selection
                    Picker("Prompt Template", selection: $selectedTemplateType) {
                        ForEach(PromptTemplateType.allCases, id: \.self) { templateType in
                            Text(templateType.displayName).tag(templateType)
                        }
                    }
                    
                    // Show custom prompt field only when Custom is selected
                    if selectedTemplateType == .custom {
                        TextField("Custom Prompt", text: $customPromptText, axis: .vertical)
                            .lineLimit(4, reservesSpace: true)
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Mode" : "New Mode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    // Update the mode's prompt template before saving
                    mode.promptTemplate = PromptTemplate(type: selectedTemplateType, customPrompt: customPromptText)
                    onSave(mode)
                    dismiss()
                }
                .disabled(mode.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                         (selectedTemplateType == .custom && customPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
        }
        .onChange(of: mode.transcriptionProvider) { _, _ in
            // Update model when provider changes
            if mode.transcriptionProvider == .voiceink {
                mode.transcriptionModel = settings.voiceInkTranscriptionModel()
            } else {
                let availableModels = mode.transcriptionProvider.models(for: .transcription)
                if !availableModels.contains(mode.transcriptionModel) {
                    mode.transcriptionModel = availableModels.first ?? ""
                }
            }
        }
        .onChange(of: mode.postProcessingProvider) { _, _ in
            // Update model when provider changes
            if mode.postProcessingProvider == .voiceink {
                mode.postProcessingModel = settings.voiceInkPostProcessingModel()
            } else {
                let availableModels = mode.postProcessingProvider.models(for: .postProcessing)
                if !availableModels.contains(mode.postProcessingModel) {
                    mode.postProcessingModel = availableModels.first ?? ""
                }
            }
        }
    }
}

#Preview {
    ModeConfigurationView(settings: AppSettings.shared) { _ in }
}
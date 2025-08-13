import SwiftUI

struct ModeConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: AppSettings
    
    @State private var mode: Mode
    @State private var isEditing: Bool
    
    let onSave: (Mode) -> Void
    
    init(mode: Mode? = nil, settings: AppSettings, onSave: @escaping (Mode) -> Void) {
        self.settings = settings
        self.onSave = onSave
        self.isEditing = mode != nil
        self._mode = State(initialValue: mode ?? Mode(name: ""))
    }
    
    var body: some View {
        Form {
            Section(header: Text("Mode Details")) {
                TextField("Mode Name", text: $mode.name)
                    .textInputAutocapitalization(.words)
            }
            
            Section(header: Text("Transcription")) {
                Picker("Provider", selection: $mode.transcriptionProvider) {
                    ForEach(Provider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                
                Picker("Model", selection: $mode.transcriptionModel) {
                    ForEach(mode.transcriptionProvider.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            }
            
            Section(header: Text("Post-processing")) {
                Picker("Provider", selection: $mode.postProcessingProvider) {
                    ForEach(Provider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                
                Picker("Model", selection: $mode.postProcessingModel) {
                    ForEach(mode.postProcessingProvider.availableLLMModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            }
            
            Section(header: Text("Custom Prompt"), 
                   footer: Text("Optional prompt to customize post-processing behavior.")) {
                TextField("Enter custom prompt...", text: $mode.customPrompt, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
            }
        }
        .navigationTitle(isEditing ? "Edit Mode" : "New Mode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(mode)
                    dismiss()
                }
                .disabled(mode.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onChange(of: mode.transcriptionProvider) { _, _ in
            // Reset model when provider changes
            if !mode.transcriptionProvider.availableModels.contains(mode.transcriptionModel) {
                mode.transcriptionModel = mode.transcriptionProvider.availableModels.first ?? ""
            }
        }
        .onChange(of: mode.postProcessingProvider) { _, _ in
            // Reset model when provider changes
            if !mode.postProcessingProvider.availableLLMModels.contains(mode.postProcessingModel) {
                mode.postProcessingModel = mode.postProcessingProvider.availableLLMModels.first ?? ""
            }
        }
    }
}

#Preview {
    ModeConfigurationView(settings: AppSettings.shared) { _ in }
}
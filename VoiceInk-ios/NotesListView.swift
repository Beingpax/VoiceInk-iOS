import SwiftUI
import SwiftData
import AVFoundation

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

    @State private var searchText: String = ""
    @State private var showingNoModesAlert: Bool = false
    @StateObject private var recordingManager = RecordingManager()
    @StateObject private var settings = AppSettings.shared

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
                    unifiedRecordingComponent
                }
                .sheet(isPresented: $recordingManager.isRecordingSheetPresented) {
                    RecordingSheetView(
                        recordingManager: recordingManager,
                        settings: settings,
                        onCancel: { recordingManager.cancelRecording() },
                        onStop: { recordingManager.stopRecording(modelContext: modelContext) }
                    )
                    .presentationDetents([.fraction(0.4)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(16)
                    .interactiveDismissDisabled(true)
                }
                .alert(item: $recordingManager.activeRecordingAlert) { alertType in
                    switch alertType {
                    case .permissionDenied:
                        return Alert(
                            title: Text("Microphone Access Denied"),
                            message: Text("To record audio, please grant microphone access in Settings."),
                            primaryButton: .default(Text("Settings"), action: recordingManager.openSettings),
                            secondaryButton: .cancel()
                        )
                    case .busy:
                        return Alert(
                            title: Text("Microphone In Use"),
                            message: Text("Another app is using the microphone. Please try again."),
                            dismissButton: .default(Text("OK"))
                        )
                    case .generic(let error):
                        let nsError = error as NSError
                        if nsError.domain == NSOSStatusErrorDomain && nsError.code == 561017449 { // '!act' error
                             return Alert(
                                title: Text("Microphone In Use"),
                                message: Text("Another app is using the microphone. Please try again."),
                                dismissButton: .default(Text("OK"))
                            )
                        }
                        return Alert(
                            title: Text("Recording Failed"),
                            message: Text("Could not start recording: \(error.localizedDescription)"),
                            dismissButton: .default(Text("OK"))
                        )
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

    private var unifiedRecordingComponent: some View {
        Button(action: {
            if AppSettings.shared.modes.isEmpty {
                showingNoModesAlert = true
            } else {
                recordingManager.startRecordingFlow()
            }
        }) {
            Label("Start Recording", systemImage: "mic.fill")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .controlSize(.large)
        .padding(.horizontal, 32)
        .padding(.bottom, 12)
        .alert("No Modes Found", isPresented: $showingNoModesAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please create a new mode in Settings before recording.")
        }
    }

    // MARK: - Helper Functions
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets { modelContext.delete(filteredNotes[index]) }
        }
    }
}

#Preview {
    NotesListView()
        .modelContainer(for: [Transcription.self])
}



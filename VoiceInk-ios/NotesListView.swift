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
    @EnvironmentObject private var recordingManager: RecordingManager
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
                .navigationBarTitleDisplayMode(.large)
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
                    .presentationDetents([.height(220)])
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
                .onReceive(NotificationCenter.default.publisher(for: .stopRecordingFromKeyboard)) { _ in
                    if recordingManager.isRecording {
                        recordingManager.stopRecording(modelContext: modelContext)
                    }
                }
        }
    }

    private var content: some View {
        Group {
            if filteredNotes.isEmpty {
                emptyState
            } else {
                List {
                    Section(header: sectionHeader) {
                        ForEach(filteredNotes) { note in
                            NavigationLink(destination: NoteDetailView(note: note)) {
                                NoteRowView(note: note)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text("Recent")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(filteredNotes.count)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 88, height: 88)
                Image(systemName: "waveform")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text("No notes yet")
                .font(.title3.weight(.semibold))
            Text("Tap Start Recording to capture your first note.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
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
        .buttonBorderShape(.capsule)
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
        .environmentObject(RecordingManager())
}



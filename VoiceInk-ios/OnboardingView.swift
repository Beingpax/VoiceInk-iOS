//
//  OnboardingView.swift
//  VoiceInk-ios
//
//  Onboarding flow for first-time users
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0
    @Binding var isOnboardingComplete: Bool
    
    var body: some View {
        ZStack {
            // Step-by-step views without swiping
            if currentStep == 0 {
                WelcomeOnboardingView(currentStep: $currentStep)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else if currentStep == 1 {
                ModelDownloadOnboardingView(currentStep: $currentStep)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else if currentStep == 2 {
                ReadyOnboardingView(isOnboardingComplete: $isOnboardingComplete)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
        .ignoresSafeArea(.all)
    }
}

struct WelcomeOnboardingView: View {
    @Binding var currentStep: Int
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Header
            VStack(spacing: 24) {
                AppIconView()
                    .frame(width: 100, height: 100)
                    .cornerRadius(22)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                
                VStack(spacing: 12) {
                    Text("Welcome to VoiceInk")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Transform your thoughts into text effortlessly.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Features
            VStack(alignment: .leading, spacing: 24) {
                FeatureRow(
                    icon: "mic.fill",
                    title: "Instant Recording",
                    description: "Capture your thoughts with a single tap, anytime, anywhere."
                )
                
                FeatureRow(
                    icon: "bolt.fill",
                    title: "Accurate Transcription",
                    description: "Leverage powerful AI models for precise speech-to-text conversion."
                )
                
                FeatureRow(
                    icon: "icloud.slash.fill",
                    title: "Works Offline",
                    description: "Transcribe without an internet connection using local models."
                )
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Continue Button
            VStack {
                Button("Get Started") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = 1
                    }
                }
                .buttonStyle(OnboardingButtonStyle())
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

struct ModelDownloadOnboardingView: View {
    @Binding var currentStep: Int
    @StateObject private var modelManager = LocalModelManager.shared
    @State private var hasStartedDownload = false
    @State private var showError = false
    @State private var showDownloadConfirmation = false
    
    var baseModel = WhisperModel.baseModel
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Header
            VStack(spacing: 24) {
                Image(systemName: "cpu")
                    .font(.system(size: 70))
                    .foregroundColor(.accentColor)
                
                VStack(spacing: 12) {
                    Text("Offline Transcription")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Download a local model to transcribe audio even without an internet connection.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            
            Spacer()
            
            // Model Info Card
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(baseModel.displayName)
                                .font(.headline).fontWeight(.semibold)
                            Text(baseModel.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if baseModel.isDownloaded {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title)
                        } else if modelManager.isDownloading[baseModel.id] == true {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Image(systemName: "icloud.and.arrow.down")
                                .foregroundColor(.accentColor)
                                .font(.title)
                        }
                    }
                    
                    if modelManager.isDownloading[baseModel.id] == true {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Downloading...")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                Spacer()
                                Text("\(Int((modelManager.downloadProgress[baseModel.id] ?? 0) * 100))%")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.accentColor)
                            }
                            
                            ProgressView(value: modelManager.downloadProgress[baseModel.id] ?? 0)
                                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Bottom Action Buttons
            VStack(spacing: 16) {
                if let isDownloading = modelManager.isDownloading[baseModel.id], isDownloading {
                    Button("Downloading...") {}
                        .buttonStyle(OnboardingButtonStyle())
                        .disabled(true)
                    
                } else if baseModel.isDownloaded {
                    Button("Continue") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = 2
                        }
                    }
                    .buttonStyle(OnboardingButtonStyle())
                } else {
                    Button(action: {
                        showDownloadConfirmation = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download Model (\(baseModel.size))")
                        }
                    }
                    .buttonStyle(OnboardingButtonStyle())
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .alert("Download Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(modelManager.downloadError ?? "An unknown error occurred.")
        }
        .alert("Download Model", isPresented: $showDownloadConfirmation) {
            Button("Download") {
                downloadModel()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To enable offline transcription, a \(baseModel.size) model needs to be downloaded. This may incur data charges if you are not on Wi-Fi.")
        }
        .onChange(of: modelManager.downloadError) { error in
            if error != nil {
                showError = true
            }
        }
    }
    
    private func downloadModel() {
        Task {
            do {
                hasStartedDownload = true
                try await modelManager.downloadModel(baseModel)
            } catch {
                print("Download failed: \(error)")
            }
        }
    }
}

struct ReadyOnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Success Icon & Text
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.green)
                
                VStack(spacing: 12) {
                    Text("You're All Set!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Start recording your thoughts and ideas.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
            
            // How it works
            VStack(alignment: .leading, spacing: 24) {
                HowItWorksStep(
                    number: "1",
                    title: "Record",
                    description: "Tap the record button to capture your thoughts."
                )
                
                HowItWorksStep(
                    number: "2",
                    title: "Transcribe",
                    description: "AI converts your speech to text automatically."
                )
                
                HowItWorksStep(
                    number: "3",
                    title: "Save & Organize",
                    description: "Your notes are saved and ready for review."
                )
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Start Button
            VStack {
                Button("Start Using VoiceInk") {
                    completeOnboarding()
                }
                .buttonStyle(OnboardingButtonStyle())
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
    
    private func completeOnboarding() {
        // Create default mode for first-time user
        DefaultModeManager.shared.setupForFirstTimeUser()
        
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.easeInOut(duration: 0.5)) {
            isOnboardingComplete = true
        }
    }
}

// MARK: - Supporting Views

struct OnboardingButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isEnabled ? Color.accentColor : Color.gray)
            .cornerRadius(16)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.accentColor)
                .frame(width: 40, alignment: .center)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct HowItWorksStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - App Icon Helper

struct AppIconView: View {
    var body: some View {
        // Try to get the app icon from the bundle
        if let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIconsDictionary = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIconsDictionary["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last,
           let appIcon = UIImage(named: lastIcon) {
            Image(uiImage: appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // Fallback to system icon
            Image(systemName: "app.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
        }
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}

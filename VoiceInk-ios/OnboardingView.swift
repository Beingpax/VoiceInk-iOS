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
            
            // App Icon/Logo
            VStack(spacing: 24) {
                AppIconView()
                    .frame(width: 80, height: 80)
                    .cornerRadius(16)
                
                VStack(spacing: 16) {
                    Text("Welcome to VoiceInk")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Transform your thoughts into text")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            // Features
            VStack(spacing: 24) {
                FeatureRow(
                    icon: "mic.circle.fill",
                    title: "Record instantly",
                    description: "Capture your thoughts with a simple tap"
                )
                
                FeatureRow(
                    icon: "text.bubble.fill",
                    title: "Transcribe accurately",
                    description: "Local AI models or cloud services for precision"
                )
                
                FeatureRow(
                    icon: "square.and.arrow.down.fill",
                    title: "Works offline",
                    description: "No internet? No problem with local models"
                )
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Continue Button
            VStack(spacing: 16) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = 1
                    }
                }) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 32)
                
                Text("Let's set up VoiceInk for you")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 50)
        }
        .background(Color(.systemBackground))
    }
}

struct ModelDownloadOnboardingView: View {
    @Binding var currentStep: Int
    @StateObject private var modelManager = LocalModelManager.shared
    @State private var hasStartedDownload = false
    @State private var showError = false
    
    var baseModel = WhisperModel.baseModel
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Header
            VStack(spacing: 24) {
                AppIconView()
                    .frame(width: 80, height: 80)
                    .cornerRadius(16)
                
                VStack(spacing: 16) {
                    Text("Download Local Model")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("We'll download a transcription model for offline transcription")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            
            Spacer()
            
            // Model Info Card - styled like LocalModelManagementView
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(baseModel.displayName)
                                .font(.headline)
                            Text(baseModel.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Action indicator
                        if baseModel.isDownloaded {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                        } else if modelManager.isDownloading[baseModel.id] == true {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        } else {
                            Image(systemName: "icloud.and.arrow.down")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                    }
                    
                    // Progress indicator when downloading
                    if modelManager.isDownloading[baseModel.id] == true {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Downloading...")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Spacer()
                                Text("\(Int((modelManager.downloadProgress[baseModel.id] ?? 0) * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            ProgressView(value: modelManager.downloadProgress[baseModel.id] ?? 0)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Bottom Action Buttons
            VStack(spacing: 16) {
                if let isDownloading = modelManager.isDownloading[baseModel.id], isDownloading {
                    // Show disabled continue button while downloading
                    Button(action: {}) {
                        Text("Downloading...")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.gray)
                            .cornerRadius(16)
                    }
                    .disabled(true)
                } else if baseModel.isDownloaded {
                    // Show continue button when downloaded
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStep = 2
                        }
                    }) {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.blue)
                            .cornerRadius(16)
                    }
                } else {
                    // Show download button when not downloaded
                    Button(action: downloadModel) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download Model")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
        .background(Color(.systemBackground))
        .alert("Download Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(modelManager.downloadError ?? "Unknown error occurred")
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
            
            // Success Icon
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                VStack(spacing: 16) {
                    Text("You're All Set!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Start recording your thoughts and ideas")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            // How it works
            VStack(spacing: 24) {
                Text("How it works")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(spacing: 20) {
                    HowItWorksStep(
                        number: "1",
                        title: "Record",
                        description: "Tap the record button to capture your thoughts"
                    )
                    
                    HowItWorksStep(
                        number: "2",
                        title: "Transcribe",
                        description: "AI converts your speech to text automatically"
                    )
                    
                    HowItWorksStep(
                        number: "3",
                        title: "Save & Organize",
                        description: "Your notes are saved and ready to review"
                    )
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Start Button
            VStack(spacing: 16) {
                Button(action: {
                    completeOnboarding()
                }) {
                    Text("Start Using VoiceInk")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 32)
                
                Text("Ready to capture your first thought?")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 50)
        }
        .background(Color(.systemBackground))
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.easeInOut(duration: 0.5)) {
            isOnboardingComplete = true
        }
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct HowItWorksStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Text(number)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
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

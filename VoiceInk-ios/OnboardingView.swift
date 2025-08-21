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
        TabView(selection: $currentStep) {
            WelcomeOnboardingView(currentStep: $currentStep)
                .tag(0)
            
            ModelDownloadOnboardingView(currentStep: $currentStep)
                .tag(1)
            
            ReadyOnboardingView(isOnboardingComplete: $isOnboardingComplete)
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
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
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
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
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
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
            
            // Model Info Card
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(baseModel.displayName)
                            .font(.headline)
                        Text(baseModel.size)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if baseModel.isDownloaded {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Ready")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(.blue)
                            Text("Not downloaded")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Progress indicator only
                if let isDownloading = modelManager.isDownloading[baseModel.id], isDownloading {
                    VStack(spacing: 12) {
                        ProgressView(value: modelManager.downloadProgress[baseModel.id] ?? 0.0)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Text("Downloading... \(Int((modelManager.downloadProgress[baseModel.id] ?? 0.0) * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
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

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}

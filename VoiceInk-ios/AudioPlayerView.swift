import SwiftUI

struct AudioPlayerView: View {
    let audioFilePath: String
    let duration: Double
    @StateObject private var player = AudioPlayer()
    
    var body: some View {
        VStack(spacing: 0) {
            if player.isLoading {
                // Simple loading state
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.blue)
                    
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            } else {
                // Clean player interface
                HStack(spacing: 16) {
                    // Play/Pause button
                    Button(action: {
                        if player.isPlaying {
                            player.pause()
                        } else {
                            player.play()
                        }
                    }) {
                        Circle()
                            .fill(.blue)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .offset(x: player.isPlaying ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    // Progress and time
                    VStack(spacing: 8) {
                        // Simple progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(.quaternaryLabel))
                                    .frame(height: 4)
                                
                                // Progress
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.blue)
                                    .frame(width: geometry.size.width * CGFloat(player.currentTime / max(player.duration, 1)), height: 4)
                            }
                        }
                        .frame(height: 4)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let progress = value.location.x / max(value.startLocation.x, 1)
                                    let seekTime = progress * player.duration
                                    player.seek(to: max(0, min(seekTime, player.duration)))
                                }
                        )
                        
                        // Time display
                        HStack {
                            Text(timeString(player.currentTime))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Text(timeString(player.duration))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .onAppear {
            if FileManager.default.fileExists(atPath: audioFilePath) {
                player.loadAudio(from: audioFilePath)
            }
        }
        .onDisappear {
            player.stop()
        }
    }
    
    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds)
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }
}

#Preview {
    AudioPlayerView(audioFilePath: "", duration: 120)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
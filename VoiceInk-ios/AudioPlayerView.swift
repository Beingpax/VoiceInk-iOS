import SwiftUI

struct AudioPlayerView: View {
    let audioFilePath: String
    let duration: Double
    @StateObject private var player = AudioPlayer()
    
    var body: some View {
        Group {
            if player.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 12) {
                    // Play/pause button
                    Button(action: {
                        if player.isPlaying {
                            player.pause()
                        } else {
                            player.play()
                        }
                    }) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.blue))
                    }
                    .buttonStyle(.plain)
                    
                    // Slider and time
                    VStack(spacing: 4) {
                        Slider(value: Binding(
                            get: { player.currentTime },
                            set: { player.seek(to: $0) }
                        ), in: 0...max(1, player.duration))
                        .tint(.blue)
                        
                        HStack {
                            Text(timeString(player.currentTime))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(timeString(player.duration))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
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
        return String(format: "%02d:%02d", m, r)
    }
}

#Preview {
    AudioPlayerView(audioFilePath: "", duration: 120)
        .padding()
}
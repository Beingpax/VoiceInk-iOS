//
//  AudioRecorder.swift
//  VoiceInk-ios
//

import Foundation
import Combine
import AVFoundation

@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording: Bool = false
    @Published var currentRecordingURL: URL?
    @Published var currentDuration: TimeInterval = 0
    @Published var levelsHistory: [CGFloat] = [] // normalized 0...1

    private var audioRecorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private let sessionManager = AudioSessionManager.shared

    func startRecording() throws {
        // Use session manager to activate audio session
        try sessionManager.activateSessionForRecording()

        let filename = "recording_\(Int(Date().timeIntervalSince1970)).wav"
        let url = Self.recordingsDirectory().appendingPathComponent(filename)

        // Whisper-compatible format: 16kHz mono WAV
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        guard audioRecorder?.record() == true else {
            // Provide a more descriptive error to help with debugging
            let userInfo = [NSLocalizedDescriptionKey: "Failed to start AVAudioRecorder. The record() method returned false. This often happens in the background if the audio session is not configured correctly or if there is a conflict with another app."]
            throw NSError(domain: "com.prakashjoshipax.VoiceInk.AudioRecorder", code: 1001, userInfo: userInfo)
        }

        currentRecordingURL = url
        isRecording = true
        currentDuration = 0

        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.audioRecorder?.updateMeters()
                self.currentDuration += 0.1

                if let power = self.audioRecorder?.averagePower(forChannel: 0) {
                    // Convert dB (-160..0) to 0..1
                    let normalized = max(0, min(1, (power + 60) / 60))
                    self.levelsHistory.append(CGFloat(normalized))
                    if self.levelsHistory.count > 40 { self.levelsHistory.removeFirst(self.levelsHistory.count - 40) }
                }
            }
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        meterTimer?.invalidate()
        meterTimer = nil
        isRecording = false
        levelsHistory.removeAll()
        
        // Schedule session deactivation with timeout instead of immediate deactivation
        sessionManager.scheduleDeactivation()
    }

    func discard() {
        audioRecorder?.stop()
        audioRecorder = nil
        meterTimer?.invalidate()
        meterTimer = nil
        isRecording = false
        levelsHistory.removeAll()
        
        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        currentRecordingURL = nil
        currentDuration = 0
        
        // Schedule session deactivation after discard as well
        sessionManager.scheduleDeactivation()
    }

    static func recordingsDirectory() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Recordings")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {}



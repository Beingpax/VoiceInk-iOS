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

    func startRecording() throws {
        // Configure audio session for background recording
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

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
            throw NSError(domain: "Audio", code: -1) 
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
        
        // Deactivate audio session when done recording
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func discard() {
        stopRecording()
        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        currentRecordingURL = nil
        currentDuration = 0
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



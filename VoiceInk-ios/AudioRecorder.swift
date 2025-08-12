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
        try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try AVAudioSession.sharedInstance().setActive(true)

        let filename = "recording_\(Int(Date().timeIntervalSince1970)).m4a"
        let url = Self.recordingsDirectory().appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.isMeteringEnabled = true
        guard audioRecorder?.record() == true else { throw NSError(domain: "Audio", code: -1) }

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



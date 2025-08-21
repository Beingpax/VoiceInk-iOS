//
//  RiffWaveUtils.swift
//  VoiceInk-ios
//
//  Simple WAV file decoding utilities for Whisper
//  Adapted from whisper.swiftui demo
//

import Foundation

/// Decode WAV file to float samples for Whisper transcription
func decodeWaveFile(_ url: URL) throws -> [Float] {
    let data = try Data(contentsOf: url)
    
    // Basic WAV header validation
    guard data.count > 44 else {
        throw NSError(domain: "RiffWaveUtils", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid WAV file - too small"])
    }
    
    // Extract samples starting from byte 44 (after WAV header)
    let floats = stride(from: 44, to: data.count, by: 2).map { offset in
        let short = data[offset..<offset + 2].withUnsafeBytes {
            Int16(littleEndian: $0.load(as: Int16.self))
        }
        // Convert to normalized float (-1.0 to 1.0)
        return max(-1.0, min(Float(short) / 32767.0, 1.0))
    }
    
    return floats
}

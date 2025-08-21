//
//  LibWhisper.swift
//  VoiceInk-ios
//
//  Core whisper.cpp wrapper for local transcription
//

import Foundation
import UIKit
import whisper

enum WhisperError: Error {
    case couldNotInitializeContext
    case modelNotFound
    case transcriptionFailed
}

// Meet Whisper C++ constraint: Don't access from more than one thread at a time.
actor WhisperContext {
    private var context: OpaquePointer
    
    init(context: OpaquePointer) {
        self.context = context
    }
    
    deinit {
        whisper_free(context)
    }
    
    func fullTranscribe(samples: [Float]) async -> String {
        // Leave 2 processors free (i.e. the high-efficiency cores).
        let maxThreads = max(1, min(8, cpuCount() - 2))
        print("Whisper: Using \(maxThreads) threads for transcription")
        
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        "en".withCString { en in
            // Optimized parameters for VoiceInk use case
            params.print_realtime   = false  // Don't print to console
            params.print_progress   = false
            params.print_timestamps = false  // VoiceInk doesn't need timestamps
            params.print_special    = false
            params.translate        = false
            params.language         = en
            params.n_threads        = Int32(maxThreads)
            params.offset_ms        = 0
            params.no_context       = true
            params.single_segment   = false
            params.suppress_blank   = true   // Skip blank segments
            
            whisper_reset_timings(context)
            
            let result = samples.withUnsafeBufferPointer { samples in
                whisper_full(context, params, samples.baseAddress, Int32(samples.count))
            }
            
            if result != 0 {
                print("Whisper: Transcription failed with code \(result)")
            }
        }
        
        return getTranscription()
    }
    
    private func getTranscription() -> String {
        var transcription = ""
        let segmentCount = whisper_full_n_segments(context)
        
        for i in 0..<segmentCount {
            if let segmentText = whisper_full_get_segment_text(context, i) {
                let text = String(cString: segmentText)
                transcription += text
            }
        }
        
        return transcription.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func createContext(path: String) throws -> WhisperContext {
        var params = whisper_context_default_params()
        
#if targetEnvironment(simulator)
        params.use_gpu = false
        print("Whisper: Running on simulator, using CPU")
#else
        params.flash_attn = true // Enable Metal acceleration on device
        print("Whisper: Using Metal acceleration")
#endif
        
        let context = whisper_init_from_file_with_params(path, params)
        if let context {
            return WhisperContext(context: context)
        } else {
            print("Whisper: Could not load model at \(path)")
            throw WhisperError.couldNotInitializeContext
        }
    }
}

private func cpuCount() -> Int {
    ProcessInfo.processInfo.processorCount
}

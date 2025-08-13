//
//  Note.swift
//  VoiceInk-ios
//
//  Created by AI Assistant on 12/08/2025.
//

import Foundation
import SwiftData

enum TranscriptionStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case completed = "completed"
    case failed = "failed"
}

@Model
final class Note {
    var id: UUID
    var createdAt: Date
    var title: String
    var transcript: String
    var audioFilePath: String?
    var durationSeconds: Double
    var transcriptionStatus: TranscriptionStatus
    var transcriptionError: String?
    
    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String = "New note",
        transcript: String = "",
        audioFilePath: String? = nil,
        durationSeconds: Double = 0,
        transcriptionStatus: TranscriptionStatus = .pending,
        transcriptionError: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.transcript = transcript
        self.audioFilePath = audioFilePath
        self.durationSeconds = durationSeconds
        self.transcriptionStatus = transcriptionStatus
        self.transcriptionError = transcriptionError
    }
    
    var needsTranscription: Bool {
        return transcriptionStatus == .pending || transcriptionStatus == .failed
    }
}



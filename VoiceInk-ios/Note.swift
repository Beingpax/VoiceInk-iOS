//
//  Note.swift
//  VoiceInk-ios
//
//  Created by AI Assistant on 12/08/2025.
//

import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var createdAt: Date
    var title: String
    var transcript: String
    var audioFilePath: String?
    var durationSeconds: Double
    // Removed starred/shared/post-process flags for a leaner model

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String = "New note",
        transcript: String = "",
        audioFilePath: String? = nil,
        durationSeconds: Double = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.transcript = transcript
        self.audioFilePath = audioFilePath
        self.durationSeconds = durationSeconds
    }
}



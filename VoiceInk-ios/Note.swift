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
    var isStarred: Bool
    var isShared: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String = "New note",
        transcript: String = "",
        audioFilePath: String? = nil,
        durationSeconds: Double = 0,
        isStarred: Bool = false,
        isShared: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.transcript = transcript
        self.audioFilePath = audioFilePath
        self.durationSeconds = durationSeconds
        self.isStarred = isStarred
        self.isShared = isShared
    }
}



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
    var isPostProcessed: Bool
    var postProcessorProvider: String?
    var postProcessorModel: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String = "New note",
        transcript: String = "",
        audioFilePath: String? = nil,
        durationSeconds: Double = 0,
        isStarred: Bool = false,
        isShared: Bool = false,
        isPostProcessed: Bool = false,
        postProcessorProvider: String? = nil,
        postProcessorModel: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.transcript = transcript
        self.audioFilePath = audioFilePath
        self.durationSeconds = durationSeconds
        self.isStarred = isStarred
        self.isShared = isShared
        self.isPostProcessed = isPostProcessed
        self.postProcessorProvider = postProcessorProvider
        self.postProcessorModel = postProcessorModel
    }
}



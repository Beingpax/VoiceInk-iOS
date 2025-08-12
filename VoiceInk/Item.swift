//
//  Item.swift
//  VoiceInk
//
//  Created by Prakash Joshi on 12/08/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

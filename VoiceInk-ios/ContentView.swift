//
//  ContentView.swift
//  VoiceInk-ios
//
//  Created by Prakash Joshi on 12/08/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        NotesListView()
    }
}

#Preview { ContentView().modelContainer(for: [Note.self], inMemory: true) }

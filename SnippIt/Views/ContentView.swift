//
//  ContentView.swift
//  SnippIt
//
//  Created by Golam Wasy Arnob on 18.12.2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var noteManager = NoteManager()
    @State private var selectedGroup: Group? = nil
    @State private var selectedFile: File? = nil

    var body: some View {
        if noteManager.isLoggedIn {
            HStack(spacing: 0) {
                SidebarView(noteManager: noteManager, selectedFile: $selectedFile, selectedGroup: $selectedGroup)
                    .frame(minWidth: 250, maxWidth: 300)

                Divider()

                // Pass selectedFile as a Binding
                TextEditorView(noteManager: noteManager, group: selectedGroup, file: selectedFile)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
                LoginView(noteManager: noteManager)
        }
        
    }
}

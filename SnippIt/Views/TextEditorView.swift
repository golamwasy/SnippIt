//
//  TextEditorView.swift
//  SnippIt
//
//  Created by Golam Wasy Arnob on 18.12.2024.
//

import SwiftUI

struct TextEditorView: View {
    @ObservedObject var noteManager: NoteManager
    var group: Group?
    var file: File?

    @State private var content: String = "" // Local state to hold the current content

    var body: some View {
        if let group = group, let file = file {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255)) // Dark background

                        TextEditor(text: $content)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.9))
                            .padding(.top, 35)
                            .padding(.bottom, 10)
                            .padding(.horizontal, 4)
                            .background(Color.clear)
                            .ignoresSafeArea(edges: .all)
                            .onChange(of: content) {
                                handleContentChange(newContent: content, for: file, in: group)
                            }
                    }
                }
                // Feedback when saving
                if noteManager.isSaving {
                    Text("Saving...")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.top, 5)
                }
            }
            .onAppear {
                loadContent(for: file, in: group)
            }
            .onChange(of: file, { _, selectedFile in
                loadContent(for: selectedFile, in: group)
            })
            .ignoresSafeArea(edges: .all)
        } else {
            VStack {
                Text("Select a file or create a new one")
                    .foregroundColor(.gray)
                    .italic()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.95))
            .ignoresSafeArea(edges: .all)
        }
    }

    // MARK: - Helper Methods
    private func loadContent(for file: File, in group: Group) {
        // Load the content of the file when the view appears
        content = getFileContent(for: file, in: group)

    }

    private func handleContentChange(newContent: String, for file: File, in group: Group) {
        // Trigger content update in NoteManager
        if contentHasChanged(newContent: newContent, for: file, in: group) {
            noteManager.updateFileContent(file, newContent: newContent)
        }
    }

    private func getFileContent(for file: File, in group: Group) -> String {
        // Retrieve the file content from the NoteManager
        return noteManager.files.first(where: { $0.parentId == group.id && $0.id == file.id })?.content ?? ""
    }

    private func contentHasChanged(newContent: String, for file: File, in group: Group) -> Bool {
        // Check if the new content differs from the stored content
        let currentContent = getFileContent(for: file, in: group)
        return currentContent != newContent
    }
}

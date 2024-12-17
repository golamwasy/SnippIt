//
//  RenameDialog.swift
//  SnippIt
//
//  Created by Golam Wasy Arnob on 18.12.2024.
//

import SwiftUI

struct RenameView: View {
    @Binding var name: String
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            Text("Rename")
                .font(.headline)
            
            TextField("Enter new name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            HStack {
                Button("Cancel", action: onCancel)
                    .foregroundColor(.red)
                Spacer()
                Button("Save", action: onSave)
                    .disabled(name.isEmpty)
            }
            .padding()
        }
        .frame(width: 300)
        .padding()
    }
}

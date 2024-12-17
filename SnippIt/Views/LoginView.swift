//
//  LoginView.swift
//  SnippIt
//
//  Created by Golam Wasy Arnob on 18.12.2024.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var noteManager: NoteManager
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var userExists = false // Track if the user exists

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                // App Title
                Text("SnippIt")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(radius: 5)

                // Username Field
                StyledTextField(
                    placeholder: "Enter your username",
                    imageName: "person",
                    text: $username
                )

                // Password Field
                StyledTextField(
                    placeholder: "Enter your password",
                    imageName: "lock",
                    text: $password,
                    isSecure: true
                )

                // Error Message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.subheadline)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }

                // Login Button
                Button(action: {
                    handleLogin()
                }) {
                    Text("Login")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())

                // Register Button
                Button(action: {
                    handleRegister()
                }) {
                    Text("Register")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.green)
                        .cornerRadius(12)
                        .shadow(radius: 3)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(width: 400)
            .padding(30)
            .background(Color.black.opacity(0.3))
            .cornerRadius(15)
            .shadow(radius: 10)
        }
    }

    // MARK: - Login Handler
    private func handleLogin() {
        noteManager.login(username: username, password: password) { success, error in
            if let error = error {
                // Attempt to extract and decode the JSON error response
                if let jsonStartIndex = error.range(of: "{")?.lowerBound,
                   let jsonData = error[jsonStartIndex...].data(using: .utf8), // Extract JSON substring
                   let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: String],
                   let message = json["message"] {
                    // Handle JSON error message
                    if message == "Invalid user" {
                        userExists = false
                        errorMessage = "User not found. Click Register to create an account."
                    } else {
                        userExists = true
                        errorMessage = "Incorrect password. Try again."
                    }
                } else {
                    // Fallback if JSON parsing fails
                    errorMessage = "Unexpected error occurred. Please try again."
                }
            } else {
                // Login successful
                userExists = true
                errorMessage = ""
            }
        }
    }

    // MARK: - Register Handler
    private func handleRegister() {
        if userExists {
            errorMessage = "User already exists. Please log in."
        } else {
            noteManager.register(username: username, password: password) { success, error in
                if let error = error {
                    // Attempt to decode the JSON error response
                    if let jsonData = error.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: String],
                       let message = json["message"] {
                        errorMessage = "Registration failed: \(message)"
                    } else {
                        // Fallback if JSON parsing fails
                        errorMessage = "Registration failed. Please try again."
                    }
                } else if success {
                    userExists = true
                    errorMessage = "Registration successful! Please log in."
                } else {
                    errorMessage = "Unexpected error occurred. Please try again."
                }
            }
        }
    }
}

// MARK: - StyledTextField
struct StyledTextField: View {
    let placeholder: String
    let imageName: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        HStack {
            Image(systemName: imageName)
                .foregroundColor(.gray)
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1))
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 2)
    }
}

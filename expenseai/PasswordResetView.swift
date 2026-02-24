import SwiftUI

struct PasswordResetView: View {
    @State private var email = ""
    @EnvironmentObject var authService: AuthService
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let successMessage = authService.passwordResetSuccessMessage {
                    Text(successMessage)
                        .foregroundColor(.green)
                        .padding()
                        .multilineTextAlignment(.center)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                } else {
                    Text(localizationManager.localize(key: "Enter your email address to reset your password."))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding()

                    TextField("Email", text: $email)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.gray.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                        .padding(.horizontal)

                    if authService.isLoading {
                        ProgressView()
                    } else {
                        Button(action: {
                            authService.sendPasswordResetEmail(email: email)
                        }) {
                            Text(localizationManager.localize(key: "Send Reset Link"))
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .disabled(email.isEmpty)
                        .padding(.horizontal)
                    }

                    if let errorMessage = authService.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
            }
            .navigationTitle(localizationManager.localize(key: "Forgot Password"))
            .navigationBarItems(trailing: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.title2)
            })
            .onDisappear {
                authService.errorMessage = nil
                authService.passwordResetSuccessMessage = nil
            }
        }
    }
}
import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    @Binding var showLogin: Bool
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var password2 = ""
    
    var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && !password.isEmpty && password == password2
    }

    var body: some View {
        VStack(spacing: 20) {
            if let message = authService.registrationSuccessMessage {
                Spacer()
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button(action: {
                    authService.registrationSuccessMessage = nil
                    showLogin = true
                }) {
                    Text(localizationManager.localize(key: "Go to Login"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                Spacer()
            } else {
                Spacer()
                
                Text(localizationManager.localize(key: "Register"))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 2, x: 0, y: 2)
                
                VStack(spacing: 15) {
                    TextField(localizationManager.localize(key: "First name"), text: $firstName)
                        .padding()
                        .background(Color.gray.opacity(0.5))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    
                    TextField(localizationManager.localize(key: "Last name"), text: $lastName)
                        .padding()
                        .background(Color.gray.opacity(0.5))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    TextField("Email", text: $email)
                        .padding()
                        .background(Color.gray.opacity(0.5))
                        .cornerRadius(10)
                        .keyboardType(.emailAddress)
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    SecureField(localizationManager.localize(key: "Password"), text: $password)
                        .padding()
                        .background(Color.gray.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    SecureField(localizationManager.localize(key: "Password confirm"), text: $password2)
                        .padding()
                        .background(Color.gray.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                }
                .padding(.horizontal)
                
                if let errorMessage = authService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                if authService.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    Button(action: {
                        authService.register(
                            firstName: firstName,
                            lastName: lastName,
                            email: email,
                            password: password,
                            password2: password2
                        )
                    }) {
                        Text(localizationManager.localize(key: "Register"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isFormValid ? Color.blue : Color.gray)
                            .cornerRadius(10)
                    }
                    .disabled(!isFormValid)
                    .padding(.horizontal)
                }
                
                Button(action: {
                    showLogin = true
                }) {
                    (
                        Text(localizationManager.localize(key: "Already have account? "))
                        +
                        Text(localizationManager.localize(key: "Login"))
                            .fontWeight(.bold)
                    )
                    
                }
                .padding(.top)
                
                Spacer()
            }
        }
        .padding()
        .onAppear {
            authService.errorMessage = nil
            authService.registrationSuccessMessage = nil
        }
    }
}
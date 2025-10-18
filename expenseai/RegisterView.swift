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
            Spacer()
            
            Text(localizationManager.localize(key: "Register"))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black, radius: 2, x: 0, y: 2)
            
            VStack(spacing: 15) {
                TextField(localizationManager.localize(key: "First name"), text: $firstName)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1) // Тонкая рамка
                        )
                
                TextField(localizationManager.localize(key: "Last name"), text: $lastName)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1) // Тонкая рамка
                        )
                TextField("Email", text: $email)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1) // Тонкая рамка
                        )
                SecureField(localizationManager.localize(key: "Password"), text: $password)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1) // Тонкая рамка
                        )
                SecureField(localizationManager.localize(key: "Password confirm"), text: $password2)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1) // Тонкая рамка
                        )
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
            }
            
            Button(action: {
                showLogin = true
            }) {
                Text(localizationManager.localize(key: "Already have account? **Login**"))
            }
            .padding(.top)
            
            Spacer()
        }
        .padding()
    }
}

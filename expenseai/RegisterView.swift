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
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 15) {
                TextField(localizationManager.localize(key: "First name"), text: $firstName)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                TextField(localizationManager.localize(key: "Last name"), text: $lastName)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                SecureField(localizationManager.localize(key: "Password"), text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                SecureField(localizationManager.localize(key: "Password confirm"), text: $password2)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
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

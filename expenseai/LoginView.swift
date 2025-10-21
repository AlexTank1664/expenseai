import SwiftUI

struct LoginView: View {
    @Binding var showLogin: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var opacity: CGFloat = 0.9
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image("chika")
                .resizable()
                .scaledToFill()
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 10)
                .padding(.bottom, 30)
                .scaleEffect(scale)
                .opacity(opacity)
            
            Text(localizationManager.localize(key: "Pay Up Pal"))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black, radius: 2, x: 0, y: 2)
                .opacity(opacity)
                
            
            VStack(spacing: 15) {
                TextField("Email", text: $email)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(10)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1) // Тонкая рамка
                        )
                HStack {
                    ZStack {
                        TextField(localizationManager.localize(key: "Password"), text: $password)
                            .textFieldStyle(.plain)
                            .opacity(isPasswordVisible ? 1 : 0)
                        
                        SecureField(localizationManager.localize(key: "Password"), text: $password)
                            .textFieldStyle(.plain)
                            .opacity(isPasswordVisible ? 0 : 1)
                    }
                    
                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray, lineWidth: 1) // Тонкая рамка
                    )
            }
            .padding(.horizontal)
            
            if authService.isLoading {
                ProgressView()
                    .padding()
            } else {
                Button(action: {
                    authService.login(email: email, password: password)
                }) {
                    Text(localizationManager.localize(key: "Login"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                        .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray, lineWidth: 1) // Тонкая рамка
                            )
                }
                .disabled(email.isEmpty || password.isEmpty)
                .padding(.horizontal)
            }
            
            Button(action: {
                
                showLogin = false
            }) {
                Text(localizationManager.localize(key: "No account yet? **Register**"))
            }
            .padding(.top)
            
            Spacer()
        }
        .padding()
    }
}

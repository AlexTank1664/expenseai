import SwiftUI

struct LoginView: View {
    @Binding var showLogin: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @EnvironmentObject var authService: AuthService

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image("login-hero-image")
                .resizable()
                .scaledToFill()
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: .gray.opacity(0.7), radius: 10, x: 0, y: 5)
                .padding(.bottom, 20)

            Text("Вход в ExpenseAI")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 15) {
                TextField("Email", text: $email)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                HStack {
                    ZStack {
                        TextField("Пароль", text: $password)
                            .textFieldStyle(.plain)
                            .opacity(isPasswordVisible ? 1 : 0)
                        
                        SecureField("Пароль", text: $password)
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
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            if authService.isLoading {
                ProgressView()
                    .padding()
            } else {
                Button(action: {
                    authService.login(email: email, password: password)
                }) {
                    Text("Войти")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .disabled(email.isEmpty || password.isEmpty)
                .padding(.horizontal)
            }
            
            Button(action: {
                showLogin = false
            }) {
                Text("Нет аккаунта? **Зарегистрироваться**")
            }
            .padding(.top)
            
            Spacer()
        }
        .padding()
    }
}
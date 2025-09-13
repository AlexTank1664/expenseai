import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authService: AuthService
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
            
            Text("Регистрация")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 15) {
                TextField("Имя", text: $firstName)
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
                
                TextField("Фамилия", text: $lastName)
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
                
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
                
                SecureField("Пароль", text: $password)
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)
                
                SecureField("Повторите пароль", text: $password2)
                    .padding()
                    .background(Color(UIColor.systemGray6))
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
                    Text("Зарегистрироваться")
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
                Text("Уже есть аккаунт? **Войти**")
            }
            .padding(.top)
            
            Spacer()
        }
        .padding()
    }
}
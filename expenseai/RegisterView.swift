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
        // не забудь - тексты -  NSLocalizedString(   , comment: "")
        ZStack {
            Image("oboi1")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
                .blur(radius: 3)
            
            VStack(spacing: 20) {
                Spacer()
                
                Text(NSLocalizedString( "Registration"  , comment: ""))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(spacing: 15) {
                    TextField(NSLocalizedString(  "Name" , comment: ""), text: $firstName)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    TextField(NSLocalizedString(  "Surname" , comment: ""), text: $lastName)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    TextField(NSLocalizedString(  "Email" , comment: ""), text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    SecureField(NSLocalizedString(  "Password" , comment: ""), text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    SecureField(NSLocalizedString(  "Repeat password" , comment: ""), text: $password2)
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
                        Text(NSLocalizedString(  "Register" , comment: ""))
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
                    Text(NSLocalizedString( "Already have an account? Login"  , comment: ""))
                }
                .padding(.top)
                
                Spacer()
            }
            .padding()
        }
    }
}

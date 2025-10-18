import SwiftUI

struct AuthenticationRootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    @State private var showLogin = true
    
    // Для success alert'а
    @State private var showSuccessAlert = false
    // Для error alert'а
    @State private var showErrorAlert = false
    
    var body: some View {
        WallpaperBackgroundView{
            
            VStack {
                if showLogin {
                    LoginView(showLogin: $showLogin)
                } else {
                    RegisterView(showLogin: $showLogin)
                }
            }
            .onReceive(authService.$registrationSuccessMessage) { message in
                if message != nil {
                    // When registration is successful, show the alert and switch to the login view
                    self.showSuccessAlert = true
                    self.showLogin = true
                }
            }
            .alert(isPresented: $showSuccessAlert) {
                Alert(
                    title: Text(localizationManager.localize(key: "Success!")),
                    message: Text(authService.registrationSuccessMessage ?? ""),
                    dismissButton: .default(Text("OK")) {
                        // Reset the message after the alert is dismissed
                        authService.registrationSuccessMessage = nil
                    }
                )
            }
            .onChange(of: authService.errorMessage) {
                if authService.errorMessage != nil {
                    showErrorAlert = true
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {
                    // Сбрасываем сообщение об ошибке, когда Alert закрывается
                    authService.errorMessage = nil
                }
            } message: {
                Text(authService.errorMessage ?? localizationManager.localize(key: "Unknown error ocurred."))
            }
        }
    }
}

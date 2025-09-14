import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        // ZStack allows us to easily switch between views
        // without complex conditional logic in the view hierarchy.
        ZStack {
            if !authService.isAuthenticated {
                AuthenticationRootView()
            } else {
                // When authenticated, we check if the user profile is loaded.
                if authService.isUserLoaded {
                    // If user is loaded, show the main application view
                    MainTabView()
                } else {
                    // While the user profile is loading, show a splash screen
                    SplashScreenView()
                }
            }
        }
    }
}
import SwiftUI
import CoreData

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    
    @State private var isMinimumTimeElapsed = false

    var body: some View {
        // Replace Group with ZStack to allow modifiers
        ZStack {
            if authService.isAuthenticated && authService.isUserLoaded && isMinimumTimeElapsed {
                // State 1: All ready, show main app
                MainTabView()
            } else if authService.isAuthenticated {
                // State 2: Token exists, but we are waiting for user data or the timer. Show splash.
                SplashScreenView()
            } else {
                // State 3: No token, user needs to log in or register.
                AuthenticationRootView()
            }
        }
        .onAppear(perform: startTimer)
    }
    
    private func startTimer() {
        guard !isMinimumTimeElapsed else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.isMinimumTimeElapsed = true
        }
    }
}

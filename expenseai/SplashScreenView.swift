import SwiftUI

struct SplashScreenView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    var body: some View {
        ZStack {
            // A dark background often looks good for splash screens
            Color(white: 0.1).edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Spacer()
                
                Image("login-hero-image")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 250, height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 10)
                    .padding(.bottom, 30)
                
                Text(localizationManager.localize(key: "PayUp pal"))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .padding(.top, 20)
                
                Spacer()
                Spacer()
            }
        }
    }
}

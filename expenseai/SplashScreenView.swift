import SwiftUI

struct SplashScreenView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var scale: CGFloat = 0.8
    @State private var opacity: CGFloat = 0.0
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            WallpaperBackgroundView {
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
                    
                    ProgressView()
                    
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2.5)
                        .padding(.top, 20)
                        .opacity(opacity)
                        .shadow(color: .black, radius: 2, x: 0, y: 2)
                    
                    Spacer()
                    Spacer()
                }
                .onAppear {
                    // Start animation sequence
                    withAnimation(.easeOut(duration: 0.5)) {
                        scale = 1.0
                        opacity = 1.0
                    }
                    
                    // After 4 seconds, fade out
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation(.easeIn(duration: 1.0)) {
                            opacity = 0.0
                        }
                    }
                }
            }
        }
    }
}

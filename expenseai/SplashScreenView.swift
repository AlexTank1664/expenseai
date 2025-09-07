import SwiftUI

struct SplashScreenView: View {
    @State private var blurRadius: CGFloat = 50
    
    var body: some View {
        ZStack {
            Image("oboi1")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
                .blur(radius: blurRadius)
                .onAppear {
                    withAnimation(.easeInOut(duration: 3)) {
                        blurRadius = 3
                    }
                }
            
            VStack(spacing: 20) {
                Spacer()
                
                Image("login-hero-image")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 250, height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 10)
                    .padding(.bottom, 30)
                
                Text(NSLocalizedString("Pay Up, Pal", comment: ""))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(NSLocalizedString("group finance program", comment: ""))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
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

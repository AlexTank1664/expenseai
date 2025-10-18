import SwiftUI

struct WallpaperBackgroundView<Content: View>: View {
    @AppStorage("selectedWallpaper") private var selectedWallpaper: String = "oboi3"
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            Image(selectedWallpaper)
                .resizable()
                .scaledToFill()
                .blur(radius: 3)
                .ignoresSafeArea()
            
            content
        }
    }
}

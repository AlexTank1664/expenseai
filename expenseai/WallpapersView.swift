import SwiftUI

struct WallpapersView: View {
    @Binding var selectedWallpaper: String
    @Environment(\.dismiss) private var dismiss
    
    let wallpapers = [
        "oboi1",
        "oboi2",
        "oboi3",
        "oboi4",
        "oboi5",
        "oboi6",
        "oboi7"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    ForEach(wallpapers, id: \.self) { wallpaper in
                        Button(action: {
                            selectedWallpaper = wallpaper
                        }) {
                            ZStack {
                                Image(wallpaper)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 200)
                                    .clipped()
                                //    .overlay(
                                  //      Rectangle()
                                    //        .fill(.ultraThinMaterial)
                                  //  )
                                
                                if selectedWallpaper == wallpaper {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.blue)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedWallpaper == wallpaper ? Color.blue : Color.clear, lineWidth: 3)
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Wallpapers")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}

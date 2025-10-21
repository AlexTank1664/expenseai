import SwiftUI

struct SettingsView: View {
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @AppStorage("selectedWallpaper") private var selectedWallpaper: String = "oboi3"
    @EnvironmentObject var authService: AuthService
    @State private var showLanguageMenu = false
    @State private var selectedLanguage: String = Locale.preferredLanguages.first ?? "en"
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var showWallpapers = false
    
    var body: some View {
      
                Form {
                    
                    Section(header: Text(localizationManager.localize(key: "Appearance"))) {
                        Picker(localizationManager.localize(key: "Theme"), selection: $colorScheme) {
                            Text(localizationManager.localize(key: "System")).tag("system")
                            Text(localizationManager.localize(key: "Light")).tag("light")
                            Text(localizationManager.localize(key: "Dark")).tag("dark")
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    
                    
                    // Язык
                    Section(header: Text(localizationManager.localize(key: "Language"))) {
                        Picker("Language", selection: $localizationManager.currentLanguage) {
                            Text("English").tag("en")
                            Text("Russian").tag("ru")
                            // Добавьте другие языки по аналогии
                        }
                        .pickerStyle(.menu)
                        .labelsHidden() // Скрывает заголовок "Language" у самого пикера
                    }
                    
                    Section(header: Text(localizationManager.localize(key: "Data management"))) {
                        NavigationLink(destination: ManageCurrenciesView()) {
                            Text(localizationManager.localize(key: "Active currencies"))
                        }
                        // Wallpaper section
                        
                        Button(action: {
                            showWallpapers = true
                        }) {
                            HStack {
                                Text(localizationManager.localize(key: "Select wallpaper"))
                                Spacer()
                                Image(selectedWallpaper)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .clipped()
                                    .cornerRadius(8)
                            }
                        }
                        .sheet(isPresented: $showWallpapers) {
                            WallpapersView(selectedWallpaper: $selectedWallpaper)
                        }
                    }
                    if let user = authService.currentUser {
                        Section(header: Text(localizationManager.localize(key: "User details"))) {
                            HStack {
                                Text("ID")
                                Spacer()
                                Text(String(user.id))
                                    .foregroundColor(.gray)
                            }
                            HStack {
                                Text(localizationManager.localize(key: "First name"))
                                Spacer()
                                Text(user.first_name)
                                    .foregroundColor(.gray)
                            }
                            HStack {
                                Text(localizationManager.localize(key: "Last name"))
                                Spacer()
                                Text(user.last_name)
                                    .foregroundColor(.gray)
                            }
                            HStack {
                                Text("Email")
                                Spacer()
                                Text(user.email)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Section {
                        Button(role: .destructive, action: {
                            authService.logout()
                        }) {
                            Text(localizationManager.localize(key: "Logout"))
                        }
                    }
                }
           
                .navigationTitle(localizationManager.localize(key: "Settings"))
                
                
                
            
        }
        
    }



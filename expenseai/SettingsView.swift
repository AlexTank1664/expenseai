import SwiftUI

struct SettingsView: View {
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @EnvironmentObject var authService: AuthService
    @State private var showLanguageMenu = false
    @State private var selectedLanguage: String = Locale.preferredLanguages.first ?? "en"
    @EnvironmentObject private var localizationManager: LocalizationManager
    
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
            

//             Section(header: Text(LocalizationManager.localize(key: "LanguageSectionHeader"))) {
//                 Button(action: {
//                     self.showLanguageMenu.toggle()
//                 }) {
//                     Text(selectedLanguage == "ru" ? "Русский" : "English")
//                 }
//                 .sheet(isPresented: $showLanguageMenu) {
//                     VStack(spacing: 20) {
//                         Button(action: {
//                             LocalizationManager.changeLanguage(to: "ru")
//                             selectedLanguage = "ru"
//                             self.showLanguageMenu.toggle()
//                             refreshInterface()
//                         }) {
//                             Text(LocalizationManager.localize(key: "RussianOption"))
//                         }
//                         
//                         Button(action: {
//                             LocalizationManager.changeLanguage(to: "en")
//                             selectedLanguage = "en"
//                             self.showLanguageMenu.toggle()
//                             refreshInterface()
//                         }) {
//                             Text(LocalizationManager.localize(key: "EnglishOption"))
//                         }
//                     }
//                     .padding()
//                 }
//             }
            
            Section(header: Text(localizationManager.localize(key: "Data management"))) {
                NavigationLink(destination: ManageCurrenciesView()) {
                    Text(localizationManager.localize(key: "Active currencies"))
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



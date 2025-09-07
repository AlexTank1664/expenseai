import SwiftUI

struct SettingsView: View {
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @EnvironmentObject var authService: AuthService
    @State private var showLanguageMenu = false
    @State private var selectedLanguage: String = Locale.preferredLanguages.first ?? "en"
    
    var body: some View {
            Form {
                // Внешний вид
                Section(header: Text(LocalizationManager.localize(key: "ThemePickerLabel"))) {
                    Picker(LocalizationManager.localize(key: "Theme"), selection: $colorScheme) {
                        Text(LocalizationManager.localize(key: "SystemOption")).tag("system")
                        Text(LocalizationManager.localize(key: "LightOption")).tag("light")
                        Text(LocalizationManager.localize(key: "DarkOption")).tag("dark")
                    }
                    .pickerStyle(.segmented)
                }
               
                NavigationLink(destination: ManageCurrenciesView()) {
                    Text(LocalizationManager.localize(key: "Working currencies"))
                }
                // Язык
                Section(header: Text(LocalizationManager.localize(key: "LanguageSectionHeader"))) {
                    Button(action: {
                        self.showLanguageMenu.toggle()
                    }) {
                        Text(selectedLanguage == "ru" ? "Русский" : "English")
                    }
                    .sheet(isPresented: $showLanguageMenu) {
                        VStack(spacing: 20) {
                            Button(action: {
                                LocalizationManager.changeLanguage(to: "ru")
                                selectedLanguage = "ru"
                                self.showLanguageMenu.toggle()
                                refreshInterface()
                            }) {
                                Text(LocalizationManager.localize(key: "RussianOption"))
                            }
                            
                            Button(action: {
                                LocalizationManager.changeLanguage(to: "en")
                                selectedLanguage = "en"
                                self.showLanguageMenu.toggle()
                                refreshInterface()
                            }) {
                                Text(LocalizationManager.localize(key: "EnglishOption"))
                            }
                        }
                        .padding()
                    }
                }
            
            // Информация о пользователе
            if let user = authService.currentUser {
                           Section(header: Text("UserInfoHeader")) {
                               HStack {
                                   Text("IDLabel")
                                   Spacer()
                                   Text(String(user.id))
                                       .foregroundColor(.gray)
                               }
                               HStack {
                                   Text("FirstNameLabel")
                                   Spacer()
                                   Text(user.first_name)
                                       .foregroundColor(.gray)
                               }
                               HStack {
                                   Text("LastNameLabel")
                                   Spacer()
                                   Text(user.last_name)
                                       .foregroundColor(.gray)
                               }
                               HStack {
                                   Text("EmailLabel")
                                   Spacer()
                                   Text(user.email)
                                       .foregroundColor(.gray)
                               }
                           }
                       }
                       
                       // Кнопка выхода
                       Section {
                           Button(role: .destructive, action: {
                               authService.logout()
                           }) {
                               Text("LogoutButtonText")
                           }
                       }
                   }
            .navigationTitle(Text(LocalizationManager.localize(key: "NavigationTitle")))
         }
         
         // Метод для обновления элементов интерфейса
         func refreshInterface() {
             UIApplication.shared.sendAction(#selector(UIApplication.refreshAllViews), to: nil, from: nil, for: nil)
             func localize(key: String) -> String {
                     return NSLocalizedString(key, comment: "")
                 }
         }
     }

     // Расширение для принудительного обновления интерфейса
     extension UIApplication {
         @objc public func refreshAllViews() {}
     }

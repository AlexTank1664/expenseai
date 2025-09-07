import SwiftUI

struct SettingsView: View {
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @EnvironmentObject var authService: AuthService

    var body: some View {
        Form {
            

            Section(header: Text("Внешний вид")) {
                Picker("Тема", selection: $colorScheme) {
                    Text("Системная").tag("system")
                    Text("Светлая").tag("light")
                    Text("Темная").tag("dark")
                }
                .pickerStyle(.segmented)
            }
            
            Section(header: Text("Управление данными")) {
                NavigationLink(destination: ManageCurrenciesView()) {
                    Text("Рабочие валюты")
                }
            }
            if let user = authService.currentUser {
                Section(header: Text("Сведения о пользователе")) {
                    HStack {
                        Text("ID")
                        Spacer()
                        Text(String(user.id))
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Имя")
                        Spacer()
                        Text(user.first_name)
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Фамилия")
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
                    Text("Выйти")
                }
            }
        }
        .navigationTitle("Настройки")
    }
}

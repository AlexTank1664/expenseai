import SwiftUI

struct SettingsView: View {
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @EnvironmentObject var authService: AuthService

    var body: some View {
        Form {
            

            Section(header: Text("Appearance")) {
                Picker("Theme", selection: $colorScheme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }
            
            Section(header: Text("Data management")) {
                NavigationLink(destination: ManageCurrenciesView()) {
                    Text("Active currencies")
                }
            }
            if let user = authService.currentUser {
                Section(header: Text("User details")) {
                    HStack {
                        Text("ID")
                        Spacer()
                        Text(String(user.id))
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("First name")
                        Spacer()
                        Text(user.first_name)
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Last name")
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
                    Text("Logout")
                }
            }
        }
        .navigationTitle("Settings")
    }
}

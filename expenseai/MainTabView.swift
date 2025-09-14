import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        TabView {
            NavigationView {
                GroupsListView()
            }
            .tabItem {
                Label("Группы", systemImage: "person.3.fill")
            }
            
            NavigationView {
                ParticipantsListView()
            }
            .tabItem {
                Label("Участники", systemImage: "person.2.fill")
            }

            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("Настройки", systemImage: "gearshape.fill")
            }
        }
    }
}
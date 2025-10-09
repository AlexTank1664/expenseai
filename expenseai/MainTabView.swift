import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        TabView {
            NavigationView {
                GroupsListView()
            }
            .tabItem {
                Label("Groups", systemImage: "person.3.fill")
            }
            
            NavigationView {
                ParticipantsListView()
            }
            .tabItem {
                Label("Participants", systemImage: "person.2.fill")
            }

            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
    }
}

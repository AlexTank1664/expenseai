import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    var body: some View {
        TabView {
            NavigationView {
                GroupsListView()
            }
            .tabItem {
                Label(localizationManager.localize(key: "Groups"), systemImage: "person.3.fill")
            }
            
            NavigationView {
                ParticipantsListView()
            }
            .tabItem {
                Label(localizationManager.localize(key: "Participants"), systemImage: "person.2.fill")
            }

            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label(localizationManager.localize(key: "Settings"), systemImage: "gearshape.fill")
            }
        }
    }
}

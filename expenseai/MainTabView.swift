import SwiftUI

struct MainTabView: View {
    @State private var showingParticipantsList = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                // Tab 1: Groups
                NavigationStack {
                    GroupsListView()
                }
                .tabItem {
                    Label("Группы", systemImage: "person.3.fill")
                }
                .tag(0)

                // Placeholder Tab for the central button space
                Text("").tabItem { Text("") }.tag(1)

                // Tab 2: Settings
                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("Настройки", systemImage: "gear")
                }
                .tag(2)
            }

            // Custom central button that overlays the TabView
            Button(action: {
                showingParticipantsList = true
            }) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .padding(15)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(radius: 5)
            }
            // Adjust the vertical offset to position the button correctly over the tab bar
            .offset(y: -25)
        }
        .sheet(isPresented: $showingParticipantsList) {
            // Presenting the list of participants in a sheet.
            // Wrapping in NavigationStack to allow navigation from the list (e.g., to edit a participant).
            NavigationStack {
                ParticipantsListView()
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService())
        .environment(\.managedObjectContext, DataController.shared.container.viewContext)
}
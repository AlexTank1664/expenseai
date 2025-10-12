import SwiftUI
import CoreData

struct GroupMembersView: View {
    @ObservedObject var group: Group
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    var body: some View {
        List {
            Section(header: Text("Participants")) {
                ForEach(group.membersArray, id: \.id) { particapant in
                    Text(particapant.name ?? "Unknown")
                }
            }
        }
        .navigationTitle("Group participants")
    }
}

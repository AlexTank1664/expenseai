import SwiftUI
import CoreData

struct GroupMembersView: View {
    @ObservedObject var group: Group
    
    var body: some View {
        List {
            Section(header: Text("Участники")) {
                ForEach(group.membersArray, id: \.id) { particapant in
                    Text(particapant.name ?? "Unknown")
                }
            }
        }
        .navigationTitle("Участники группы")
    }
}

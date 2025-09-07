import SwiftUI
import CoreData

struct GroupMembersView: View {
    @ObservedObject var group: Group
    //  NSLocalizedString(   , comment: "")
    var body: some View {
        List {
            Section(header: Text(NSLocalizedString( "Participants"  , comment: ""))) {
                ForEach(group.membersArray, id: \.id) { particapant in
                    Text(particapant.name ?? "Unknown")
                }
            }
        }
        .navigationTitle(NSLocalizedString(  "Members of group" , comment: ""))
    }
}

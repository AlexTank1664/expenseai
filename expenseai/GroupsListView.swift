import SwiftUI
import CoreData

struct GroupsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: Group.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Group.name, ascending: true)]
    ) var groups: FetchedResults<Group>
    
    @State private var showingAddGroup = false
    @State private var showingAddParticipant = false
    @State private var groupToEdit: Group?
    @State private var searchText = ""

    var filteredGroups: [Group] {
        if searchText.isEmpty {
            return Array(groups)
        } else {
            return groups.filter { $0.name?.localizedCaseInsensitiveContains(searchText) ?? false }
        }
    }

    var body: some View {
        List {
            ForEach(filteredGroups, id: \.id) { group in
                NavigationLink(destination: GroupExpensesView(group: group)) {
                    VStack(alignment: .leading) {
                        Text(group.name ?? "Unknown")
                        Text("Участников: \(group.members?.count ?? 0)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .swipeActions {
                    Button(action: { self.groupToEdit = group }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
            .onDelete(perform: deleteGroups)
        }
        .navigationTitle("Группы")
        .searchable(text: $searchText, prompt: "Поиск групп")
        .modifier(GroupsListNavigation(
            showingAddGroup: $showingAddGroup,
            showingAddParticipant: $showingAddParticipant,
            groupToEdit: $groupToEdit
        ))
    }

    private func deleteGroups(offsets: IndexSet) {
        withAnimation {
            offsets.map { filteredGroups[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

fileprivate struct GroupsListNavigation: ViewModifier {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var showingAddGroup: Bool
    @Binding var showingAddParticipant: Bool
    @Binding var groupToEdit: Group?

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddGroup = true }) {
                        Image(systemName: "plus")
                    }
                }
//                ToolbarItem(placement: .bottomBar) {
//                    HStack {
//                        Spacer()
//                        Button(action: { showingAddParticipant = true }) {
//                            Image(systemName: "person.badge.plus")
//                                .font(.title2)
//                        }
//                        Spacer()
//                    }
//                }
            }
            .sheet(isPresented: $showingAddGroup) {
                GroupEditView()
            }
            .sheet(item: $groupToEdit) { group in
                GroupEditView(group: group)
            }
            .sheet(isPresented: $showingAddParticipant) {
                ParticipantEditView(participant: nil)
            }
    }
}
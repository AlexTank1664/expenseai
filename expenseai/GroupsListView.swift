import SwiftUI
import CoreData

struct GroupsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var localizationManager: LocalizationManager

    @FetchRequest(
        entity: Group.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Group.name, ascending: true)],
        predicate: NSPredicate(format: "isSoftDeleted == NO")
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
            //Text("Current language is: \(localizationManager.currentLanguage)")
            ForEach(filteredGroups, id: \.id) { group in
                NavigationLink(destination: GroupExpensesView(group: group)) {
                    VStack(alignment: .leading) {
                        Text(group.name ?? "Unknown")
                        Text(localizationManager.localize(key: "Participants") + ": \(group.members?.count ?? 0)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .swipeActions {
                    Button(action: { self.groupToEdit = group }) {
                        Label(localizationManager.localize(key: "Edit"), systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
            .onDelete(perform: deleteGroups)
        }
        .navigationTitle(Text(localizationManager.localize(key: "Groups")))

        .searchable(text: $searchText, prompt: localizationManager.localize(key: "Group search"))
        .modifier(GroupsListNavigation(
            showingAddGroup: $showingAddGroup,
            showingAddParticipant: $showingAddParticipant,
            groupToEdit: $groupToEdit
        ))
    }

    private func deleteGroups(offsets: IndexSet) {
        withAnimation {
            // We don't need authService here, as this is a user action.
            // When syncing, the server will know who deleted it.
            // However, for consistency, let's add it. We'll need the authService.
            // Let's assume for now we don't have it and just set the flag.
            // The `updatedBy` logic can be added later if needed.
            offsets.map { filteredGroups[$0] }.forEach { group in
                group.isSoftDeleted = true
                group.updatedAt = Date()
                group.needsSync = true
                // If you have authService, you would add:
                // group.updatedBy = Int64(authService.currentUser?.id ?? 0)
            }
            try? viewContext.save()
        }
    }
}

fileprivate struct GroupsListNavigation: ViewModifier {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var syncEngine: SyncEngine
    @Binding var showingAddGroup: Bool
    @Binding var showingAddParticipant: Bool
    @Binding var groupToEdit: Group?
    
    // State for sync functionality
    @State private var isSyncing = false
    @State private var syncError: SyncError?
    @State private var showErrorAlert = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSyncing {
                        ProgressView()
                    } else {
                        Button(action: {
                            Task {
                                await performSync()
                            }
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                }
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
            .alert("Syncronization error", isPresented: $showErrorAlert, presenting: syncError) { error in
                Button("OK", role: .cancel) { }
            } message: { error in
                Text(error.localizedDescription)
            }
    }
    
    private func performSync() async {
        isSyncing = true
        do {
            try await syncEngine.sync()
        } catch let error as SyncError {
            self.syncError = error
            self.showErrorAlert = true
        } catch {
            // Обработка других, неизвестных ошибок
            self.syncError = .unknownError(error)
            self.showErrorAlert = true
        }
        isSyncing = false
    }
}

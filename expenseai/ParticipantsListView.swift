import SwiftUI
import CoreData

fileprivate enum ActiveSheet: Identifiable {
    case participantEditor(Participant?)
    #if os(iOS)
    case contactImporter
    #endif
    
    var id: String {
        switch self {
        case .participantEditor(let participant):
            return "participant-\(participant?.id?.uuidString ?? "new")"
        #if os(iOS)
        case .contactImporter:
            return "importer"
        #endif
        }
    }
}

struct ParticipantsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: Participant.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Participant.isSoftDeleted, ascending: true),
            NSSortDescriptor(keyPath: \Participant.name, ascending: true)
        ]
    ) var participants: FetchedResults<Participant>
    
    @State private var activeSheet: ActiveSheet?
    @State private var showingDeleteConfirmation = false
    @State private var offsetsToDelete: IndexSet?
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        List {
            ForEach(participants, id: \.id) { participant in
                Button(action: {
                    if !participant.isSoftDeleted {
                        activeSheet = .participantEditor(participant)
                    }
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(participant.name ?? "Unknown")
                                .font(.headline)
                            
                            if participant.isSoftDeleted {
                                Text("(" + localizationManager.localize(key: "marked as deleted")  + ")")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        if let email = participant.email, !email.isEmpty {
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text(email)
                            }
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        }
                        
                        if let phone = participant.phone, !phone.isEmpty {
                            HStack {
                                Image(systemName: "phone.fill")
                                Text(phone)
                            }
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .disabled(participant.isSoftDeleted)
                .foregroundColor(.primary)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if participant.isSoftDeleted {
                        Button {
                            restoreParticipant(participant)
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.green)
                    }
                }
            }
            .onDelete(perform: confirmDelete)
        }
        .navigationTitle(localizationManager.localize(key: "Participants"))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                #if os(iOS)
                Button(action: {
                    activeSheet = .contactImporter
                }) {
                    Image(systemName: "person.crop.circle.badge.plus")
                }
                #endif
                
                Button(action: {
                    activeSheet = .participantEditor(nil)
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .participantEditor(let participant):
                ParticipantEditView(participant: participant)
            #if os(iOS)
            case .contactImporter:
                ContactPickerView()
            #endif
            }
        }
        .alert(isPresented: $showingDeleteConfirmation) {
            Alert(
                title: Text("Confirm Deletion"),
                message: Text("Are you sure you want to delete this participant? A participant can only be deleted if they are not involved in any group as a payer or a recipient."),
                primaryButton: .destructive(Text("Delete")) {
                    if let offsets = offsetsToDelete {
                        deleteParticipants(offsets: offsets)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func confirmDelete(offsets: IndexSet) {
        self.offsetsToDelete = offsets
        self.showingDeleteConfirmation = true
    }

    private func restoreParticipant(_ participant: Participant) {
        guard let userID = authService.currentUser?.id else { return }
        withAnimation {
            participant.objectWillChange.send()
            participant.isSoftDeleted = false
            participant.updatedAt = Date()
            participant.updatedBy = Int64(userID)
            participant.needsSync = true
            try? viewContext.save()
        }
    }

    private func deleteParticipants(offsets: IndexSet) {
        guard let userID = authService.currentUser?.id else { return }
        withAnimation {
            offsets.map { participants[$0] }.forEach { participant in
                participant.isSoftDeleted = true
                participant.updatedAt = Date()
                participant.updatedBy = Int64(userID)
                participant.needsSync = true
            }
            try? viewContext.save()
        }
    }
}
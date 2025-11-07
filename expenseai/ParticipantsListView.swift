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
    @State private var participantToDelete: Participant?
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        List {
            ForEach(participants, id: \.id) { participant in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(participant.name ?? "Unknown")
                                .font(.headline)
                            
                            if participant.isSoftDeleted {
                                Text("(to be deleted)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            
                            // --- НАЧАЛО ИЗМЕНЕНИЙ ---
                            // Проверяем, совпадает ли email участника с email'ом
                            // текущего залогиненного пользователя.
                            if let participantEmail = participant.email,
                               let currentUserEmail = authService.currentUser?.email,
                               !participantEmail.isEmpty,
                               participantEmail.caseInsensitiveCompare(currentUserEmail) == .orderedSame {
                                
                                Text("(current user)")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            // --- КОНЕЦ ИЗМЕНЕНИЙ ---
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
                    Spacer()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !participant.isSoftDeleted {
                        activeSheet = .participantEditor(participant)
                    }
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
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if !participant.isSoftDeleted {
                        Button {
                            // This action is now neutral. It just sets the data.
                            participantToDelete = participant
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red) // This makes the swipe action background red.
                    }
                }
            }
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
        // This is the new, correct way to handle alerts for list items.
        // It watches the `participantToDelete` state and presents the alert when it's not nil.
        .alert(item: $participantToDelete) { participant in
            Alert(
                title: Text("Confirm Deletion"),
                message: Text("Are you sure you want to delete this participant? A participant can only be deleted if they are not involved in any group as a payer or a recipient."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteParticipant(participant)
                },
                secondaryButton: .cancel()
            )
        }
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

    private func deleteParticipant(_ participant: Participant) {
        guard let userID = authService.currentUser?.id else { return }
        withAnimation {
            participant.isSoftDeleted = true
            participant.updatedAt = Date()
            participant.updatedBy = Int64(userID)
            participant.needsSync = true
            try? viewContext.save()
        }
    }
}
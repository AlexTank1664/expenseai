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
        sortDescriptors: [NSSortDescriptor(keyPath: \Participant.name, ascending: true)],
        predicate: NSPredicate(format: "isSoftDeleted == NO")
    ) var participants: FetchedResults<Participant>
    
    @State private var activeSheet: ActiveSheet?
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        List {
            ForEach(participants, id: \.id) { participant in
                Button(action: {
                    activeSheet = .participantEditor(participant)
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(participant.name ?? "Unknown")
                            .font(.headline)
                        
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
                .foregroundColor(.primary)
            }
            .onDelete(perform: deleteParticipants)
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

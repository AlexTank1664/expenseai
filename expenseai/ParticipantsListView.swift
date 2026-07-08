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
                HStack(spacing: 12) {
                    // --- АВАТАР (как в WhatsApp) ---
                    avatarView(for: participant)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(participant.name ?? "Unknown")
                                .font(.headline)
                            
                            if participant.isSoftDeleted {
                                Text("(to be deleted)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                            
                            // Текущий пользователь
                            if let participantEmail = participant.email,
                               let currentUserEmail = authService.currentUser?.email,
                               !participantEmail.isEmpty,
                               participantEmail.caseInsensitiveCompare(currentUserEmail) == .orderedSame {
                                Text("(you)")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        if let email = participant.email, !email.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "envelope.fill")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        if let phone = participant.phone, !phone.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "phone.fill")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text(phone)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // --- СТАТУС СИНХРОНИЗАЦИИ (как в WhatsApp) ---
                    syncStatusIcon(for: participant)
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
                            participantToDelete = participant
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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
                ContactPickerView(onDismiss: {
                    activeSheet = nil
                })
            #endif
            }
        }
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
    
    // --- АВАТАР УЧАСТНИКА ---
    @ViewBuilder
    private func avatarView(for participant: Participant) -> some View {
        let initials = getInitials(from: participant.name ?? "?")
        let isDeleted = participant.isSoftDeleted
        let needsSync = participant.needsSync
        
        ZStack {
            // Круглый фон
            Circle()
                .fill(isDeleted ? Color.gray.opacity(0.3) : Color.blue.opacity(0.2))
                .frame(width: 44, height: 44)
            
            // Инициалы
            Text(initials)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isDeleted ? .gray : .blue)
            
            // Индикатор синхронизации в углу аватара
            if needsSync && !isDeleted {
                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                    )
                    .offset(x: 16, y: 16)
            }
        }
    }
    
    // --- СТАТУС СИНХРОНИЗАЦИИ (как в WhatsApp) ---
    @ViewBuilder
    private func syncStatusIcon(for participant: Participant) -> some View {
        if participant.isSoftDeleted {
            // Для удаленных показываем корзину
            Image(systemName: "trash.circle.fill")
                .foregroundColor(.red)
                .font(.title3)
        } else if participant.needsSync {
            // Ожидание синхронизации - облако со стрелкой
            HStack(spacing: 2) {
                Image(systemName: "icloud.and.arrow.up")
                    .foregroundColor(.orange)
                    .font(.footnote)
            }
        } else {
            // Синхронизировано - облако с галочкой
            Image(systemName: "checkmark.icloud.fill")
                .foregroundColor(.green)
                .font(.title3)
        }
    }
    
    // --- ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ---
    
    private func getInitials(from name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            let first = String(words[0].prefix(1))
            let last = String(words[1].prefix(1))
            return (first + last).uppercased()
        } else if let first = name.first {
            return String(first).uppercased()
        }
        return "?"
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

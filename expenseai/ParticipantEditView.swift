import SwiftUI
import CoreData

struct ParticipantEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    
    let participant: Participant?

    @State private var name: String
    @State private var email: String
    @State private var phone: String
    
    var navigationTitle: String {
        participant == nil ? "Новый участник" : "Редактировать"
    }

    init(participant: Participant? = nil) {
        self.participant = participant
        _name = State(initialValue: participant?.name ?? "")
        _email = State(initialValue: participant?.email ?? "")
        _phone = State(initialValue: participant?.phone ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Основная информация")) {
                    TextField("Имя участника", text: $name)
                }
                
                Section(header: Text("Контактная информация")) {
                    TextField("Email", text: $email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        #endif
                    TextField("Телефон", text: $phone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveParticipant()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveParticipant() {
        guard let userID = authService.currentUser?.id else {
            print("Error: Could not find logged in user ID.")
            return
        }

        let isNew = (participant == nil)
        let participantToSave = participant ?? Participant(context: viewContext)
        
        if isNew {
            participantToSave.id = UUID()
            participantToSave.createdAt = Date()
            participantToSave.createdBy = Int64(userID)
        }
        
        participantToSave.name = name
        participantToSave.email = email.isEmpty ? nil : email
        participantToSave.phone = phone.isEmpty ? nil : phone
        
        // Always update modification fields
        participantToSave.updatedAt = Date()
        participantToSave.updatedBy = Int64(userID)
        
        try? viewContext.save()
    }
}
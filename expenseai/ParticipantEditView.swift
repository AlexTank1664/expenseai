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
        participant == nil ? "New participant" : "Edit"
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
                Section(header: Text("General")) {
                    TextField("Participant name", text: $name)
                }
                
                Section(header: Text("Contact")) {
                    TextField("Email", text: $email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        #endif
                    TextField("Phone", text: $phone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
        participantToSave.needsSync = true
        
        try? viewContext.save()
    }
}

import SwiftUI
import CoreData
//  NSLocalizedString(   , comment: "")
struct ParticipantEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let participant: Participant?

    @State private var name: String
    @State private var email: String
    @State private var phone: String
    
    var navigationTitle: String {
        participant == nil ? NSLocalizedString(  "New participant" , comment: "") : NSLocalizedString( "Edit"  , comment: "")
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
                Section(header: Text(NSLocalizedString( "Basic information"  , comment: ""))) {
                    TextField(NSLocalizedString( "Participant name", comment: ""), text: $name)
                }
                
                Section(header: Text(NSLocalizedString(  "Contact information" , comment: ""))) {
                    TextField("Email", text: $email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        #endif
                    TextField(NSLocalizedString( "Phone number"  , comment: ""), text: $phone)
                        #if os(iOS)
                        .keyboardType(.phonePad)
                        #endif
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString(  "Cancel" , comment: "")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString(  "Save" , comment: "")) {
                        saveParticipant()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveParticipant() {
        let participantToSave = participant ?? Participant(context: viewContext)
        if participant == nil {
            participantToSave.id = UUID()
        }
        
        participantToSave.name = name
        participantToSave.email = email.isEmpty ? nil : email
        participantToSave.phone = phone.isEmpty ? nil : phone
        
        try? viewContext.save()
    }
}

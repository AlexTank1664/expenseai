import SwiftUI
import ContactsUI
import CoreData

#if os(iOS)
import UIKit

struct ContactPickerView: UIViewControllerRepresentable {
    @Environment(\.managedObjectContext) private var viewContext
    var currentGroup: Group?
    var onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPickerView
        
        init(_ parent: ContactPickerView) {
            self.parent = parent
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            var participantsToSave: [Participant] = []
            
            for contact in contacts {
                let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                guard !fullName.isEmpty else {
                    print("⚠️ Skipping contact with empty name")
                    continue
                }
                
                let email = contact.emailAddresses.first?.value as String?
                let phone = contact.phoneNumbers.first?.value.stringValue
                
                let existingParticipant = fetchParticipant(byEmail: email, byName: fullName)
                let participant: Participant
//                let isNew: Bool
                
                if let existing = existingParticipant {
                    participant = existing
//                    isNew = false
                    print("📝 Updating existing participant: \(fullName)")
                } else {
                    participant = Participant(context: parent.viewContext)
                    participant.id = UUID()
                    participant.createdAt = Date()
//                    isNew = true
                    print("✅ Creating new participant: \(fullName)")
                }
                
                participant.name = fullName
                participant.email = email
                participant.phone = phone
                participant.updatedAt = Date()
                  
                if let group = parent.currentGroup {
                    addParticipantToGroup(participant, group: group)
                }
                
                participant.needsSync = true
                participantsToSave.append(participant)
            }
            
            do {
                try parent.viewContext.save()
                print("✅ Successfully imported \(participantsToSave.count) contacts")
                for participant in participantsToSave {
                    print("   - \(participant.name ?? "Unknown") (updatedAt: \(participant.updatedAt?.description ?? "nil"))")
                }
            } catch {
                print("❌ Failed to save contacts: \(error)")
                parent.viewContext.rollback()
            }
            
            //parent.onDismiss()
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            
            //parent.onDismiss()
        }
        
        private func fetchParticipant(byEmail email: String?, byName name: String) -> Participant? {
            // 1. Сначала ищем по email (если он есть) среди НЕ удаленных участников
            if let email = email, !email.isEmpty {
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Participant")
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "email == %@", email),
                    NSPredicate(format: "isSoftDeleted == NO")
                ])
                request.fetchLimit = 1
                
                do {
                    let results = try parent.viewContext.fetch(request)
                    if let found = results.first as? Participant {
                        return found  // ✅ Нашли активного участника по email
                    }
                } catch {
                    print("Error fetching participant by email: \(error)")
                }
            }
            
            // 2. Если по email не нашли (или email пустой) — ищем по имени среди НЕ удаленных
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Participant")
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "name == %@", name),
                NSPredicate(format: "isSoftDeleted == NO")
            ])
            request.fetchLimit = 1
            
            do {
                let results = try parent.viewContext.fetch(request)
                return results.first as? Participant  // ✅ Может быть nil, если не нашли
            } catch {
                print("Error fetching participant by name: \(error)")
                return nil
            }
        }
        
        private func addParticipantToGroup(_ participant: Participant, group: Group) {
            let currentGroups = participant.member as? Set<Group> ?? []
            if !currentGroups.contains(where: { $0.id == group.id }) {
                var updatedGroups = currentGroups
                updatedGroups.insert(group)
                participant.member = updatedGroups as NSSet
                
                let currentParticipants = group.members as? Set<Participant> ?? []
                if !currentParticipants.contains(where: { $0.id == participant.id }) {
                    var updatedParticipants = currentParticipants
                    updatedParticipants.insert(participant)
                    group.members = updatedParticipants as NSSet
                }
            }
        }
    }
}

extension Participant {
    var memberArray: [Group] {
        let set = member as? Set<Group> ?? []
        return Array(set)
    }
}
#endif

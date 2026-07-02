import SwiftUI
import ContactsUI
import CoreData

#if os(iOS)
import UIKit

struct ContactPickerView: UIViewControllerRepresentable {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    var currentGroup: Group?

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
                
                // Проверяем, существует ли уже участник с таким email
                let existingParticipant = fetchParticipant(byEmail: email)
                
                let participant: Participant
                let isNew: Bool
                
                if let existing = existingParticipant {
                    participant = existing
                    isNew = false
                    print("📝 Updating existing participant: \(fullName)")
                } else {
                    participant = Participant(context: parent.viewContext)
                    participant.id = UUID()
                    participant.createdAt = Date()
                    isNew = true
                    print("✅ Creating new participant: \(fullName)")
                }
                
                // Обновляем поля
                participant.name = fullName
                participant.email = email
                participant.phone = phone
                
                // ✅ ВАЖНО: всегда устанавливаем updatedAt
                participant.updatedAt = Date()
                
                // Добавляем в группу, если передана
                if let group = parent.currentGroup {
                    addParticipantToGroup(participant, group: group)
                }
                
                // Устанавливаем флаг синхронизации
                participant.needsSync = true
                
                participantsToSave.append(participant)
            }
            
            // Сохраняем всех участников
            do {
                try parent.viewContext.save()
                print("✅ Successfully imported \(participantsToSave.count) contacts")
                
                // Логируем каждого сохраненного участника
                for participant in participantsToSave {
                    print("   - \(participant.name ?? "Unknown") (updatedAt: \(participant.updatedAt?.description ?? "nil"))")
                }
            } catch {
                print("❌ Failed to save contacts: \(error)")
                parent.viewContext.rollback()
            }
            
            parent.dismiss()
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.dismiss()
        }
        
        // Вспомогательная функция для поиска существующего участника
        private func fetchParticipant(byEmail email: String?) -> Participant? {
            guard let email = email, !email.isEmpty else { return nil }
            
            let request: NSFetchRequest<Participant> = Participant.fetchRequest()
            request.predicate = NSPredicate(format: "email == %@", email)
            request.fetchLimit = 1
            
            do {
                return try parent.viewContext.fetch(request).first
            } catch {
                print("Error fetching participant by email: \(error)")
                return nil
            }
        }
        
        // Функция для добавления участника в группу
        private func addParticipantToGroup(_ participant: Participant, group: Group) {
            // Получаем текущие группы участника как Set
            let currentGroups = participant.member as? Set<Group> ?? []
            
            // Проверяем, есть ли уже эта группа
            if !currentGroups.contains(where: { $0.id == group.id }) {
                // Создаем новый Set с добавленной группой
                var updatedGroups = currentGroups
                updatedGroups.insert(group)
                
                // Присваиваем новый Set
                participant.member = updatedGroups as NSSet
                
                // Также добавляем участника в группу (для поддержания двусторонней связи)
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

// Расширение для удобной работы с member
extension Participant {
    var memberArray: [Group] {
        let set = member as? Set<Group> ?? []
        return Array(set)
    }
}

#endif

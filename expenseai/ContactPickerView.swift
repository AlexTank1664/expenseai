import SwiftUI
import ContactsUI
import CoreData

#if os(iOS)
import UIKit

struct ContactPickerView: UIViewControllerRepresentable {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // The CNContactPickerViewController has built-in search functionality
        // No additional configuration needed for search
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
            for contact in contacts {
                let newParticipant = Participant(context: parent.viewContext)
                newParticipant.id = UUID()
                let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                
                guard !fullName.isEmpty else {
                    parent.viewContext.rollback()
                    continue
                }
                
                newParticipant.name = fullName
                newParticipant.email = contact.emailAddresses.first?.value as String?
                newParticipant.phone = contact.phoneNumbers.first?.value.stringValue
            }

            try? parent.viewContext.save()
            parent.dismiss()
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.dismiss()
        }
    }
}
#endif
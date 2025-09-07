import SwiftUI
import CoreData

// Add this extension to your extensions file
extension Optional where Wrapped == String {
    var bound: String {
        get { self ?? "" }
        set { self = newValue }
    }
}

extension Group {
    public var membersArray: [Participant] {
        let set = members as? Set<Participant> ?? []
        return set.sorted {
            $0.name ?? "" < $1.name ?? ""
        }
    }

    public var expensesArray: [Expense] {
        let set = expenses as? Set<Expense> ?? []
        return set.sorted {
            $0.date ?? Date() > $1.date ?? Date()
        }
    }
}

extension Expense {
    public var sharesArray: [ExpenseShare] {
        let set = shares as? Set<ExpenseShare> ?? []
        return set.sorted {
            $0.participant?.name ?? "" < $1.participant?.name ?? ""
        }
    }
}

extension NSManagedObject {
    var hasBeenSaved: Bool {
        return !self.objectID.isTemporaryID
    }
}
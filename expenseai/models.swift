import CoreData

extension Participant {
    static func fetchAll(in context: NSManagedObjectContext) -> [Participant] {
        let request: NSFetchRequest<Participant> = Participant.fetchRequest()
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching participants: \(error)")
            return []
        }
    }
    
    static func create(name: String, in context: NSManagedObjectContext) {
        let participant = Participant(context: context)
        participant.id = UUID()
        participant.name = name
    }
}

extension Group {
    static func create(name: String, members: Set<Participant>, in context: NSManagedObjectContext) {
        let group = Group(context: context)
        group.id = UUID()
        group.name = name
        group.members = NSSet(set: members)
    }
}

extension Expense {
    static func create(
        amount: Double,
        description: String,
        paidBy: Participant,
        group: Group,
        shares: [Participant: Double],
        in context: NSManagedObjectContext
    )  {
        let expense = Expense(context: context)
        expense.id = UUID()
        expense.amount = amount
        expense.desc = description
        expense.paidBy = paidBy
        expense.group = group
        expense.date = Date()
        
        for (participant, shareAmount) in shares {
            let expenseShare = ExpenseShare(context: context)
            expenseShare.id = UUID()
            expenseShare.participant = participant
            expenseShare.amount = shareAmount
            expenseShare.expense = expense
        }
    }
}
import SwiftUI
import CoreData

struct ExpenseDetailView: View {
    @ObservedObject var expense: Expense
    @State private var showingEditExpense = false
    //  NSLocalizedString(   , comment: "")
    var body: some View {
        List {
            detailsSection
            sharesSection
        }
        .navigationTitle(NSLocalizedString(  "Expense details" , comment: ""))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(NSLocalizedString(  "Edit" , comment: "")) {
                    showingEditExpense = true
                }
            }
        }
        .sheet(isPresented: $showingEditExpense) {
            ExpenseEditView(expense: expense)
        }
    }
    
    @ViewBuilder
    private var detailsSection: some View {
        Section {
            if let desc = expense.desc, !desc.isEmpty {
                VStack(alignment: .leading) {
                    Text(NSLocalizedString(  "Description:" , comment: ""))
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(desc)
                }
            }
            
            HStack {
                Text(NSLocalizedString( "Amount:"  , comment: ""))
                
                Spacer()
                Text(formatAmount(expense.amount, currency: expense.currency))
            }

            HStack {
                Text(NSLocalizedString(  "Paid by:" , comment: ""))
                Spacer()
                Text(expense.paidBy?.name ?? "Unknown")
            }

            HStack {
                Text(NSLocalizedString( "Group:"  , comment: ""))
                Spacer()
                Text(expense.group?.name ?? "Unknown")
            }

            HStack {
                Text(NSLocalizedString(  "Date:" , comment: ""))
                Spacer()
                Text(expense.date?.formatted() ?? "Unknown")
            }
        }
    }
    
    @ViewBuilder
    private var sharesSection: some View {
        Section(header: Text(NSLocalizedString( "Distribution"  , comment: ""))) {
            ForEach(expense.sharesArray, id: \.id) { share in
                HStack {
                    Text(share.participant?.name ?? "Unknown")
                    Spacer()
                    Text(formatAmount(share.amount, currency: expense.currency))
                }
            }
        }
    }
    
    private func formatAmount(_ amount: Double, currency: Currency?) -> String {
        let symbol = currency?.symbol_native ?? ""
        let format = "%.\(currency?.decimal_digits ?? 2)f"
        let amountString = String(format: format, amount)
        return "\(amountString) \(symbol)"
    }
}

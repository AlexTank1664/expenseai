import SwiftUI
import CoreData

struct ExpenseDetailView: View {
    @ObservedObject var expense: Expense
    @State private var showingEditExpense = false
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        List {
            detailsSection
            sharesSection
        }
        .navigationTitle(localizationManager.localize(key: "Expense detail"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(localizationManager.localize(key: "Edit")) {
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
                    Text(localizationManager.localize(key: "Description") + ":")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(desc)
                }
            }
            
            HStack {
                Text(localizationManager.localize(key: "Amount") + ":")
                Spacer()
                Text(formatAmount(expense.amount, currency: expense.currency))
            }

            HStack {
                Text(localizationManager.localize(key: "Paid by") + ":")
                Spacer()
                Text(expense.paidBy?.name ?? "Unknown")
            }

            HStack {
                Text(localizationManager.localize(key: "Group") + ":")
                Spacer()
                Text(expense.group?.name ?? "Unknown")
            }

            HStack {
                Text(localizationManager.localize(key: "Paid on") + ":")
                Spacer()
                Text(expense.createdAt?.formatted() ?? "Unknown")
            }
        }
    }
    
    @ViewBuilder
    private var sharesSection: some View {
        Section(header: Text(localizationManager.localize(key: "Distribution"))) {
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

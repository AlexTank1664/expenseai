import SwiftUI
import CoreData

struct ExpenseDetailView: View {
    @ObservedObject var expense: Expense
    @State private var showingEditExpense = false

    var body: some View {
        List {
            detailsSection
            sharesSection
        }
        .navigationTitle("Детали затрат")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Редактировать") {
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
                    Text("Описание:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(desc)
                }
            }
            
            HStack {
                Text("Сумма:")
                Spacer()
                Text(formatAmount(expense.amount, currency: expense.currency))
            }

            HStack {
                Text("Оплатил:")
                Spacer()
                Text(expense.paidBy?.name ?? "Unknown")
            }

            HStack {
                Text("Группа:")
                Spacer()
                Text(expense.group?.name ?? "Unknown")
            }

            HStack {
                Text("Дата:")
                Spacer()
                Text(expense.date?.formatted() ?? "Unknown")
            }
        }
    }
    
    @ViewBuilder
    private var sharesSection: some View {
        Section(header: Text("Распределение")) {
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
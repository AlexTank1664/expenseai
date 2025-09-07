import SwiftUI
import CoreData

fileprivate enum GroupDetailTab: String, CaseIterable {
    case expenses = "Затраты"
    case balances = "Балансы"
}

struct GroupExpensesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var group: Group
    @State private var showingAddExpense = false
    @State private var showingEditGroup = false
    @State private var showingSettleUp = false
    @State private var settlementToDelete: Expense?
    
    @FetchRequest var expenses: FetchedResults<Expense>
    
    @State private var selectedTab: GroupDetailTab = .expenses
    
    init(group: Group) {
        self.group = group
        self._expenses = FetchRequest<Expense>(
            sortDescriptors: [NSSortDescriptor(keyPath: \Expense.date, ascending: false)],
            predicate: NSPredicate(format: "group == %@", group)
        )
    }
    
    var body: some View {
        VStack {
            Picker("View", selection: $selectedTab) {
                ForEach(GroupDetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            switch selectedTab {
            case .expenses:
                expensesList
            case .balances:
                BalancesView(group: group)
            }
        }
        .navigationTitle(group.name ?? "Группа")
        .modifier(GroupExpensesModals(
            group: group,
            showingAddExpense: $showingAddExpense,
            showingEditGroup: $showingEditGroup,
            showingSettleUp: $showingSettleUp,
            settlementToDelete: $settlementToDelete,
            deleteAction: deleteSettlement
        ))
    }
    
    private var expensesList: some View {
        List {
            Section(header: Text("Затраты")) {
                if expenses.isEmpty {
                    Text("Затрат пока нет")
                        .foregroundColor(.gray)
                } else {
                    ForEach(expenses) { expense in
                        if expense.is_settlement {
                            settlementRow(for: expense)
                                .onTapGesture {
                                    settlementToDelete = expense
                                }
                        } else {
                            expenseRow(for: expense)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func expenseRow(for expense: Expense) -> some View {
        NavigationLink(destination: ExpenseDetailView(expense: expense)) {
            HStack {
                Text(expense.desc ?? "No description")
                Spacer()
                Text(formatAmount(expense.amount, currency: expense.currency))
            }
        }
    }
    
    @ViewBuilder
    private func settlementRow(for expense: Expense) -> some View {
        HStack(spacing: 4) {
            Text(expense.paidBy?.name ?? "Кто-то")
            Image(systemName: "arrow.right")
            Text(expense.sharesArray.first?.participant?.name ?? "кому-то")
            Spacer()
            Text(formatAmount(expense.amount, currency: expense.currency))
        }
        .foregroundColor(.secondary)
        .listRowBackground(listRowBackgroundColor)
    }
    
    private var listRowBackgroundColor: Color {
        #if os(iOS)
        return Color(.systemGray6)
        #else
        return Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    private func formatAmount(_ amount: Double, currency: Currency?) -> String {
        let symbol = currency?.symbol_native ?? ""
        let digits = Int(currency?.decimal_digits ?? 2)
        let format = "%.\(digits)f"
        let amountString = String(format: format, amount)
        return "\(amountString) \(symbol)"
    }
    
    private func deleteSettlement(_ expense: Expense) {
        withAnimation {
            viewContext.delete(expense)
            try? viewContext.save()
        }
    }
}

fileprivate struct GroupExpensesModals: ViewModifier {
    let group: Group
    @Binding var showingAddExpense: Bool
    @Binding var showingEditGroup: Bool
    @Binding var showingSettleUp: Bool
    @Binding var settlementToDelete: Expense?
    let deleteAction: (Expense) -> Void
    
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        Button(action: { showingEditGroup = true }) {
                            Image(systemName: "pencil")
                        }
                        Button(action: { showingSettleUp = true }) {
                            Image(systemName: "arrow.right.square.fill")
                        }
                        Button(action: { showingAddExpense = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) { ExpenseEditView(group: group) }
            .sheet(isPresented: $showingEditGroup) { GroupEditView(group: group) }
            .sheet(isPresented: $showingSettleUp) { SettleUpView(group: group, payer: nil, payee: nil, amount: 0, currency: group.defaultCurrency) }
            .alert("Удалить возврат?", isPresented: .constant(settlementToDelete != nil), presenting: settlementToDelete) { expense in
                Button("Удалить", role: .destructive) {
                    deleteAction(expense)
                }
                Button("Отмена", role: .cancel) {
                    settlementToDelete = nil
                }
            } message: { expense in
                let amountString = String(format: "%.2f", expense.amount)
                Text("Вы уверены, что хотите удалить этот возврат (\(amountString) \(expense.currency?.symbol_native ?? ""))? Это действие нельзя отменить.")
            }
    }
}

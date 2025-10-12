import SwiftUI
import CoreData

fileprivate struct ParticipantBalance: Identifiable {
    let id: UUID
    let name: String
    let balances: [Currency: Double]
}

fileprivate struct DebtTransaction: Identifiable {
    let id = UUID()
    let fromParticipant: Participant
    let toParticipant: Participant
    let amount: Double
}

fileprivate struct SettlementSheetItem: Identifiable {
    let id = UUID()
    let transaction: DebtTransaction
    let currency: Currency
}

struct BalancesView: View {
    @ObservedObject var group: Group
    @State private var expandedBalanceID: UUID?
    @State private var settlementToEdit: SettlementSheetItem?
    @EnvironmentObject private var localizationManager: LocalizationManager

    private var calculatedBalances: ([ParticipantBalance], [Currency: [DebtTransaction]]) {
        calculateBalances(for: group)
    }

    var body: some View {
        let (participantBalances, debtTransactionsByCurrency) = calculatedBalances
        
        List {
            balancesSection(with: participantBalances)
            settlementsSection(with: debtTransactionsByCurrency)
        }
        .sheet(item: $settlementToEdit) { item in
            // Remove the redundant NavigationView wrapper
            SettleUpView(
                group: group,
                payer: item.transaction.fromParticipant,
                payee: item.transaction.toParticipant,
                amount: item.transaction.amount,
                currency: item.currency
            )
        }
    }

    @ViewBuilder
    private func balancesSection(with participantBalances: [ParticipantBalance]) -> some View {
        Section(header: Text(localizationManager.localize(key: "Total balance"))) {
            if participantBalances.isEmpty {
                Text(localizationManager.localize(key: "No data to calculate")).foregroundColor(.gray)
            } else {
                ForEach(participantBalances) { balance in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(balance.name)
                            Spacer()
                            balanceView(for: balance)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring()) {
                                if expandedBalanceID == balance.id {
                                    expandedBalanceID = nil
                                } else {
                                    expandedBalanceID = balance.id
                                }
                            }
                        }
                        
                        if expandedBalanceID == balance.id {
                            expandedBalanceDetailView(for: balance)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func settlementsSection(with debtTransactionsByCurrency: [Currency: [DebtTransaction]]) -> some View {
        if debtTransactionsByCurrency.isEmpty {
            Section {
                Text(localizationManager.localize(key: "No transactions needed")).foregroundColor(.gray)
            }
        } else {
            ForEach(debtTransactionsByCurrency.keys.sorted { $0.c_code ?? "" < $1.c_code ?? "" }, id: \.self) { currency in
                Section(header: Text(localizationManager.localize(key: "How to settle up") + " (\(currency.symbol_native ?? ""))")) {
                    if let transactions = debtTransactionsByCurrency[currency], !transactions.isEmpty {
                        ForEach(transactions) { transaction in
                            Button(action: {
                                settlementToEdit = SettlementSheetItem(transaction: transaction, currency: currency)
                            }) {
                                HStack(spacing: 4) {
                                    Text(transaction.fromParticipant.name ?? "Unknown")
                                    Image(systemName: "arrow.right")
                                    Text(transaction.toParticipant.name ?? "Unknown")
                                    Spacer()
                                    Text(formatAmount(transaction.amount, currency: currency))
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    } else {
                        Text(localizationManager.localize(key: "Everything is settled")).foregroundColor(.gray)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func expandedBalanceDetailView(for balance: ParticipantBalance) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().padding(.vertical, 4)

            // Expenses section
            let paidExpenses = group.expensesArray
                .filter { !$0.is_settlement && $0.paidBy?.id == balance.id && !$0.isSoftDeleted }
                .sorted { $0.createdAt ?? .distantPast > $1.createdAt ?? .distantPast }

            // --- Логика для затрат, в которых этот участник ДОЛЖЕН ---
            
            // Шаг 1: Получаем и фильтруем все доли
            let allParticipantShares = group.expensesArray.flatMap { $0.sharesArray }
                .filter {
                    // РЕКОМЕНДАЦИЯ: Заменил опасное извлечение '!' на безопасное 'guard'
                    guard let expense = $0.expense else { return false }
                    //return !expense.is_settlement && $0.participant?.id == balance.id && expense.paidBy?.id != balance.id && !expense.isSoftDeleted
                    return !expense.is_settlement && $0.participant?.id == balance.id && !expense.isSoftDeleted
                }
            
            // Шаг 2: Сортируем отфильтрованный массив
            let participantShares = allParticipantShares.sorted {
                // ИСПРАВЛЕНИЕ: Используем '?' для безопасного доступа к 'createdAt'
                ($0.expense?.createdAt ?? .distantPast) > ($1.expense?.createdAt ?? .distantPast)
            }

            // Если есть какие-либо транзакции для этого участника, показываем секцию
            if !paidExpenses.isEmpty || !participantShares.isEmpty {
                Text(localizationManager.localize(key: "Expenses"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, -4)
                
                ForEach(paidExpenses) { expense in
                    detailRow(description: expense.desc ?? localizationManager.localize(key: "No description"), amount: expense.amount, currency: expense.currency, isCredit: true)
                }
                
                ForEach(participantShares, id: \.id) { share in
                    detailRow(description: share.expense?.desc ?? localizationManager.localize(key: "No description"), amount: share.amount, currency: share.expense?.currency, isCredit: false)
                }
            }

            // Settlements section
            let settlementsPaid = group.expensesArray.filter { $0.is_settlement && $0.paidBy?.id == balance.id && !$0.isSoftDeleted }
            let settlementsReceived = group.expensesArray.filter { expense in expense.is_settlement && expense.sharesArray.contains(where: { ($0.participant)?.id == balance.id }) && !expense.isSoftDeleted }
            
            if !settlementsPaid.isEmpty || !settlementsReceived.isEmpty {
                if !paidExpenses.isEmpty || !participantShares.isEmpty {
                    Divider().padding(.vertical, 4)
                }
                Text(localizationManager.localize(key: "Debt repayment"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, -4)
                
                ForEach(settlementsReceived) { expense in
                    detailRow(description: expense.desc ?? localizationManager.localize(key: "Settlement"), amount: expense.amount, currency: expense.currency, isCredit: true)
                }
                
                ForEach(settlementsPaid) { expense in
                    detailRow(description: expense.desc ?? localizationManager.localize(key: "Settlement"), amount: expense.amount, currency: expense.currency, isCredit: false)
                }
            }
        }
        .padding(.top, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    private func detailRow(description: String, amount: Double, currency: Currency?, isCredit: Bool) -> some View {
        HStack {
            Text(description)
                .lineLimit(1)
            Spacer()
            Text("\(isCredit ? "+" : "-")\(formatAmount(amount, currency: currency))")
                .foregroundColor(isCredit ? .green : .red)
        }
        .font(.footnote)
        .padding(.leading)
    }

    @ViewBuilder
    private func balanceView(for balance: ParticipantBalance) -> some View {
        if balance.balances.count > 1 {
            Text(localizationManager.localize(key: "Multiple currencies"))
                .font(.footnote)
                .foregroundColor(.orange)
        } else if let (currency, amount) = balance.balances.first {
            Text(formatAmount(amount, currency: currency, withSign: true))
                .foregroundColor(amount < -0.01 ? .red : (amount > 0.01 ? .green : .primary))
        } else {
            Text(formatAmount(0, currency: group.defaultCurrency, withSign: true))
                .foregroundColor(.primary)
        }
    }
    
    private func formatAmount(_ amount: Double, currency: Currency?, withSign: Bool = false) -> String {
        let symbol = currency?.symbol_native ?? ""
        
        let digits = Int(currency?.decimal_digits ?? 2)
        let format: String
        
        if withSign {
            format = "%+.\(digits)f"
        } else {
            format = "%.\(digits)f"
        }
        
        let amountString = String(format: format, amount)
        
        return "\(amountString) \(symbol)"
    }
    
    private func calculateBalances(for group: Group) -> ([ParticipantBalance], [Currency: [DebtTransaction]]) {
        var balancesByCurrency: [Currency: [Participant: Double]] = [:]

        for expense in group.expensesArray.filter({ !$0.isSoftDeleted }) {
            guard let currency = expense.currency else { continue }

            if balancesByCurrency[currency] == nil {
                balancesByCurrency[currency] = [:]
                for member in group.membersArray {
                    balancesByCurrency[currency]?[member] = 0.0
                }
            }
            
            if let payer = expense.paidBy {
                balancesByCurrency[currency]?[payer, default: 0] += expense.amount
            }
            
            for share in expense.sharesArray {
                if let participant = share.participant {
                    balancesByCurrency[currency]?[participant, default: 0] -= share.amount
                }
            }
        }

        var participantBalancesForDisplay: [ParticipantBalance] = []
        var balancesPerParticipant: [Participant: [Currency: Double]] = [:]

        for (currency, participantBalances) in balancesByCurrency {
            for (participant, amount) in participantBalances {
                if abs(amount) > 0.01 {
                    if balancesPerParticipant[participant] == nil {
                        balancesPerParticipant[participant] = [:]
                    }
                    balancesPerParticipant[participant]?[currency] = amount
                }
            }
        }
        
        participantBalancesForDisplay = group.membersArray.map { participant in
            ParticipantBalance(id: participant.id!, name: participant.name ?? localizationManager.localize(key: "Unknown"), balances: balancesPerParticipant[participant] ?? [:])
        }.sorted { $0.name < $1.name }

        var transactionsByCurrency: [Currency: [DebtTransaction]] = [:]
        for (currency, participantBalances) in balancesByCurrency {
            var debtors = participantBalances.filter { $1 < -0.01 }.map { (participant: $0.key, amount: $0.value) }
            var creditors = participantBalances.filter { $1 > 0.01 }.map { (participant: $0.key, amount: $0.value) }
            var transactions: [DebtTransaction] = []

            while !debtors.isEmpty && !creditors.isEmpty {
                let debtor = debtors[0]
                let creditor = creditors[0]

                let amountToTransfer = min(-debtor.amount, creditor.amount)
                
                if amountToTransfer > 0.01 {
                    transactions.append(DebtTransaction(
                        fromParticipant: debtor.participant,
                        toParticipant: creditor.participant,
                        amount: amountToTransfer
                    ))
                }

                debtors[0].amount += amountToTransfer
                creditors[0].amount -= amountToTransfer

                if abs(debtors[0].amount) < 0.01 { debtors.removeFirst() }
                if abs(creditors[0].amount) < 0.01 { creditors.removeFirst() }
            }
            transactionsByCurrency[currency] = transactions
        }
        
        return (participantBalancesForDisplay, transactionsByCurrency)
    }
}

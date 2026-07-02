import SwiftUI
import CoreData

fileprivate struct ParticipantBalance: Identifiable {
    let id: UUID
    let name: String
    let balances: [Currency: Double]
}

fileprivate struct ParticipantSpending: Identifiable {
    let id: UUID
    let name: String
    let totalSpent: [Currency: Double]
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

fileprivate struct CurrencySpending: Identifiable {
    let id: String
    let currency: Currency
    let total: Double
    let participants: [ParticipantSpending]
}

// Структура для хранения баланса участника с группировкой по валютам для отображения
fileprivate struct ParticipantBalanceWithCurrencies: Identifiable {
    let id: UUID
    let name: String
    let balances: [Currency: Double]
    let currencies: [CurrencyBalanceItem]
}

// Структура для отображения валюты в балансе участника
fileprivate struct CurrencyBalanceItem: Identifiable {
    let id: String // код валюты
    let currency: Currency
    let amount: Double
    let expenseDetails: [ExpenseDetail] // детали расходов в этой валюте
}

// Структура для деталей расхода
fileprivate struct ExpenseDetail: Identifiable {
    let id = UUID()
    let description: String
    let amount: Double
    let isCredit: Bool // true - оплата, false - доля
    let date: Date?
}

struct BalancesView: View {
    @ObservedObject var group: Group
    @State private var expandedParticipantID: UUID?
    @State private var expandedCurrencyID: String?
    @State private var expandedSpendingCurrencyCode: String? // Для секции Total spending
    @State private var settlementToEdit: SettlementSheetItem?
    @EnvironmentObject private var localizationManager: LocalizationManager

    private var calculatedBalances: ([ParticipantBalance], [Currency: [DebtTransaction]]) {
        calculateBalances(for: group)
    }
    
    private var calculatedSpending: [ParticipantSpending] {
        calculateSpending(for: group)
    }
    
    private var spendingByCurrency: [CurrencySpending] {
        var currencyMap: [String: (currency: Currency, total: Double, participants: [ParticipantSpending])] = [:]
        
        for spending in calculatedSpending {
            for (currency, amount) in spending.totalSpent {
                let currencyCode = currency.c_code ?? "Unknown"
                if currencyMap[currencyCode] == nil {
                    currencyMap[currencyCode] = (currency: currency, total: 0, participants: [])
                }
                currencyMap[currencyCode]?.total += amount
                currencyMap[currencyCode]?.participants.append(spending)
            }
        }
        
        return currencyMap.map { (code, data) in
            CurrencySpending(
                id: code,
                currency: data.currency,
                total: data.total,
                participants: data.participants.sorted { $0.name < $1.name }
            )
        }.sorted { $0.id < $1.id }
    }
    
    // Формирование данных для отображения балансов с группировкой по валютам
    private var participantsWithCurrencies: [ParticipantBalanceWithCurrencies] {
        let (participantBalances, _) = calculatedBalances
        
        return participantBalances.map { participantBalance in
            let currencyItems = participantBalance.balances.map { (currency, amount) -> CurrencyBalanceItem in
                // Собираем детали расходов для этой валюты
                let expenseDetails = getExpenseDetails(for: participantBalance.id, currency: currency)
                
                return CurrencyBalanceItem(
                    id: currency.c_code ?? "Unknown",
                    currency: currency,
                    amount: amount,
                    expenseDetails: expenseDetails
                )
            }.sorted { $0.id < $1.id }
            
            return ParticipantBalanceWithCurrencies(
                id: participantBalance.id,
                name: participantBalance.name,
                balances: participantBalance.balances,
                currencies: currencyItems
            )
        }.sorted { $0.name < $1.name }
    }
    
    // Получение деталей расходов для участника в конкретной валюте
    private func getExpenseDetails(for participantID: UUID, currency: Currency) -> [ExpenseDetail] {
        var details: [ExpenseDetail] = []
        
        // Расходы, где участник оплатил
        let paidExpenses = group.expensesArray
            .filter {
                !$0.is_settlement &&
                $0.paidBy?.id == participantID &&
                !$0.isSoftDeleted &&
                $0.currency?.c_code == currency.c_code
            }
            .sorted { $0.createdAt ?? .distantPast > $1.createdAt ?? .distantPast }
        
        for expense in paidExpenses {
            details.append(ExpenseDetail(
                description: expense.desc ?? localizationManager.localize(key: "No description"),
                amount: expense.amount,
                isCredit: true,
                date: expense.createdAt
            ))
        }
        
        // Доли участника в расходах
        let participantShares = group.expensesArray.flatMap { $0.sharesArray }
            .filter {
                guard let expense = $0.expense else { return false }
                return !expense.is_settlement &&
                       $0.participant?.id == participantID &&
                       !expense.isSoftDeleted &&
                       expense.currency?.c_code == currency.c_code
            }
            .sorted {
                ($0.expense?.createdAt ?? .distantPast) > ($1.expense?.createdAt ?? .distantPast)
            }
        
        for share in participantShares {
            if let expense = share.expense {
                details.append(ExpenseDetail(
                    description: expense.desc ?? localizationManager.localize(key: "No description"),
                    amount: share.amount,
                    isCredit: false,
                    date: expense.createdAt
                ))
            }
        }
        
        // Сортировка по дате
        return details.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }
    
    // Проверка, есть ли транзакции для settlement по валютам
    private var hasSettlementTransactions: Bool {
        let (_, debtTransactionsByCurrency) = calculatedBalances
        return debtTransactionsByCurrency.values.contains { !$0.isEmpty }
    }

    var body: some View {
        let (_, debtTransactionsByCurrency) = calculatedBalances
        
        List {
            balancesSection()
            spendingSection()
            
            // Показываем секцию settlements только если есть транзакции
            if hasSettlementTransactions {
                settlementsSection(with: debtTransactionsByCurrency)
            }
        }
        .sheet(item: $settlementToEdit) { item in
            SettleUpView(
                group: group,
                payer: item.transaction.fromParticipant,
                payee: item.transaction.toParticipant,
                amount: item.transaction.amount,
                currency: item.currency
            )
            .environmentObject(localizationManager)
        }
    }

    @ViewBuilder
    private func balancesSection() -> some View {
        Section(header: Text(localizationManager.localize(key: "Total balance"))) {
            if participantsWithCurrencies.isEmpty {
                Text(localizationManager.localize(key: "No data to calculate")).foregroundColor(.gray)
            } else {
                ForEach(participantsWithCurrencies) { participant in
                    VStack(alignment: .leading, spacing: 4) {
                        // Заголовок участника
                        HStack {
                            Text(participant.name)
                                .font(.headline)
                            Spacer()
                            // Показываем общий баланс участника или несколько валют
                            if participant.currencies.count == 1 {
                                if let currencyItem = participant.currencies.first {
                                    Text(formatAmount(currencyItem.amount, currency: currencyItem.currency, withSign: true))
                                        .font(.headline)
                                        .foregroundColor(currencyItem.amount < -0.01 ? .red : (currencyItem.amount > 0.01 ? .green : .primary))
                                }
                            } else {
                                Text("\(participant.currencies.count) \(localizationManager.localize(key: "currencies"))")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring()) {
                                if expandedParticipantID == participant.id {
                                    expandedParticipantID = nil
                                } else {
                                    expandedParticipantID = participant.id
                                }
                            }
                        }
                        
                        // Раскрывающийся список валют для участника
                        if expandedParticipantID == participant.id {
                            VStack(alignment: .leading, spacing: 8) {
                                Divider().padding(.vertical, 4)
                                
                                ForEach(participant.currencies) { currencyItem in
                                    VStack(alignment: .leading, spacing: 4) {
                                        // Заголовок валюты - кликабельный
                                        HStack {
                                            Text(currencyItem.currency.c_code ?? "Unknown")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text(formatAmount(currencyItem.amount, currency: currencyItem.currency, withSign: true))
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(currencyItem.amount < -0.01 ? .red : (currencyItem.amount > 0.01 ? .green : .primary))
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            withAnimation(.spring()) {
                                                if expandedCurrencyID == currencyItem.id {
                                                    expandedCurrencyID = nil
                                                } else {
                                                    expandedCurrencyID = currencyItem.id
                                                }
                                            }
                                        }
                                        
                                        // Детали расходов по валюте
                                        if expandedCurrencyID == currencyItem.id && !currencyItem.expenseDetails.isEmpty {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Divider().padding(.vertical, 2)
                                                
                                                Text(localizationManager.localize(key: "Expenses"))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .padding(.bottom, 2)
                                                
                                                ForEach(currencyItem.expenseDetails) { detail in
                                                    HStack {
                                                        Text(detail.description)
                                                            .font(.caption)
                                                            .lineLimit(1)
                                                        Spacer()
                                                        Text("\(detail.isCredit ? "+" : "-")\(formatAmount(detail.amount, currency: currencyItem.currency))")
                                                            .font(.caption)
                                                            .foregroundColor(detail.isCredit ? .green : .red)
                                                    }
                                                    .padding(.leading, 8)
                                                }
                                            }
                                            .padding(.top, 4)
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                        }
                                    }
                                    .padding(.vertical, 2)
                                    
                                    if currencyItem.id != participant.currencies.last?.id {
                                        Divider().padding(.vertical, 2)
                                    }
                                }
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    @ViewBuilder
    private func spendingSection() -> some View {
        Section {
            if spendingByCurrency.isEmpty {
                Text(localizationManager.localize(key: "No data to calculate")).foregroundColor(.gray)
            } else {
                ForEach(spendingByCurrency) { currencySpending in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(currencySpending.currency.c_code ?? "Unknown")
                                .font(.headline)
                            Spacer()
                            Text(formatAmount(currencySpending.total, currency: currencySpending.currency))
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring()) {
                                if expandedSpendingCurrencyCode == currencySpending.id {
                                    expandedSpendingCurrencyCode = nil
                                } else {
                                    expandedSpendingCurrencyCode = currencySpending.id
                                }
                            }
                        }
                        
                        if expandedSpendingCurrencyCode == currencySpending.id {
                            VStack(alignment: .leading, spacing: 8) {
                                Divider().padding(.vertical, 4)
                                
                                ForEach(currencySpending.participants) { participant in
                                    HStack {
                                        Text(participant.name)
                                            .font(.subheadline)
                                        Spacer()
                                        Text(formatAmount(participant.totalSpent[currencySpending.currency] ?? 0, currency: currencySpending.currency))
                                            .font(.subheadline)
                                            .foregroundColor(.green)
                                    }
                                    .padding(.leading, 8)
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text(localizationManager.localize(key: "Total spending"))
        }
    }
    
    @ViewBuilder
    private func settlementsSection(with debtTransactionsByCurrency: [Currency: [DebtTransaction]]) -> some View {
        // Фильтруем только валюты, у которых есть транзакции
        let currenciesWithTransactions = debtTransactionsByCurrency.filter { !$0.value.isEmpty }
        
        ForEach(currenciesWithTransactions.keys.sorted { $0.c_code ?? "" < $1.c_code ?? "" }, id: \.self) { currency in
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
                }
            }
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
    
    private func calculateSpending(for group: Group) -> [ParticipantSpending] {
        var spendingByParticipant: [Participant: [Currency: Double]] = [:]
        
        for member in group.membersArray {
            spendingByParticipant[member] = [:]
        }
        
        for expense in group.expensesArray.filter({ !$0.isSoftDeleted && !$0.is_settlement }) {
            guard let currency = expense.currency else { continue }
            
            if let payer = expense.paidBy {
                if spendingByParticipant[payer]?[currency] == nil {
                    spendingByParticipant[payer]?[currency] = 0
                }
                spendingByParticipant[payer]?[currency]? += expense.amount
            }
        }
        
        let result = group.membersArray.map { participant in
            let currencyData = spendingByParticipant[participant] ?? [:]
            var totalSpent: [Currency: Double] = [:]
            
            for (currency, spent) in currencyData {
                if spent > 0.01 {
                    totalSpent[currency] = spent
                }
            }
            
            return ParticipantSpending(
                id: participant.id!,
                name: participant.name ?? localizationManager.localize(key: "Unknown"),
                totalSpent: totalSpent
            )
        }.sorted { $0.name < $1.name }
        
        return result
    }
}

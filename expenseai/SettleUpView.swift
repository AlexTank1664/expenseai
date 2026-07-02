import SwiftUI
import CoreData

struct SettleUpView: View {
    @ObservedObject var group: Group
    let payer: Participant?
    let payee: Participant?
    let amount: Double
    let currency: Currency?
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    // FetchRequest для получения всех активных валют
    @FetchRequest(
        entity: Currency.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Currency.currency_name, ascending: true)],
        predicate: NSPredicate(format: "is_active == YES")
    ) var currencies: FetchedResults<Currency>
    
    @State private var settlementAmount: String = ""
    @State private var settlementDate: Date = Date()
    @State private var settlementDescription: String = ""
    @State private var selectedPayer: Participant?
    @State private var selectedPayee: Participant?
    @State private var selectedCurrency: Currency?
    
    // Проверяем, вызван ли View из балансов (с предзаполненными данными)
    private var isFromBalances: Bool {
        return payer != nil && payee != nil && amount > 0
    }
    
    private var participants: [Participant] {
        group.membersArray.sorted { $0.name ?? "" < $1.name ?? "" }
    }
    
    // Получаем доступные валюты для выбора
    private var availableCurrencies: [Currency] {
        var available = Array(currencies)
        
        // Если есть переданная валюта, но она не в списке активных - добавляем её
        if let currency = currency, !available.contains(where: { $0.id == currency.id }) {
            available.insert(currency, at: 0)
        }
        
        return available
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(localizationManager.localize(key: "Settlement Details"))) {
                    // Выбор плательщика
                    if isFromBalances {
                        // Из балансов - показываем фиксированного плательщика
                        HStack {
                            Text(localizationManager.localize(key: "From"))
                            Spacer()
                            Text(payer?.name ?? "Unknown")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // Из кнопки - показываем Picker для выбора
                        Picker(localizationManager.localize(key: "From"), selection: $selectedPayer) {
                            Text(localizationManager.localize(key: "Select payer")).tag(nil as Participant?)
                            ForEach(participants, id: \.id) { participant in
                                Text(participant.name ?? "Unknown").tag(participant as Participant?)
                            }
                        }
                        .onChange(of: selectedPayer) { oldValue, newValue in
                            updateDescription()
                        }
                    }
                    
                    // Выбор получателя
                    if isFromBalances {
                        // Из балансов - показываем фиксированного получателя
                        HStack {
                            Text(localizationManager.localize(key: "To"))
                            Spacer()
                            Text(payee?.name ?? "Unknown")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // Из кнопки - показываем Picker для выбора
                        Picker(localizationManager.localize(key: "To"), selection: $selectedPayee) {
                            Text(localizationManager.localize(key: "Select payee")).tag(nil as Participant?)
                            ForEach(participants, id: \.id) { participant in
                                Text(participant.name ?? "Unknown").tag(participant as Participant?)
                            }
                        }
                        .onChange(of: selectedPayee) { oldValue, newValue in
                            updateDescription()
                        }
                    }
                    
                    // Поле суммы
                    HStack {
                        Text(localizationManager.localize(key: "Amount"))
                        Spacer()
                        TextField("0.00", text: $settlementAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // Выбор валюты
                    if isFromBalances {
                        // Из балансов - показываем фиксированную валюту
                        HStack {
                            Text(localizationManager.localize(key: "Currency"))
                            Spacer()
                            Text(currency?.symbol_native ?? currency?.c_code ?? "Unknown")
                                .foregroundColor(.secondary)
                            Text(currency?.c_code ?? "")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    } else {
                        // Из кнопки - показываем Picker для выбора валюты
                        if !availableCurrencies.isEmpty {
                            Picker(localizationManager.localize(key: "Currency"), selection: $selectedCurrency) {
                                ForEach(availableCurrencies, id: \.self) { currency in
                                    Text("\(currency.symbol_native ?? currency.c_code ?? "Unknown")")
                                        .tag(currency as Currency?)
                                }
                            }
                            .onChange(of: selectedCurrency) { oldValue, newValue in
                                updateDescription()
                            }
                        } else {
                            HStack {
                                Text(localizationManager.localize(key: "Currency"))
                                Spacer()
                                Text(localizationManager.localize(key: "No currencies available"))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    DatePicker(localizationManager.localize(key: "Date"), selection: $settlementDate, displayedComponents: .date)
                    
                    HStack {
                        Text(localizationManager.localize(key: "Description"))
                        Spacer()
                        TextField(localizationManager.localize(key: "Settlement"), text: $settlementDescription)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section {
                    Button(action: saveSettlement) {
                        Text(localizationManager.localize(key: "Create Settlement"))
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.blue)
                    .disabled(!isFormValid())
                }
            }
            .navigationTitle(localizationManager.localize(key: "Settle Up"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localize(key: "Cancel")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupInitialValues()
            }
        }
    }
    
    private func setupInitialValues() {
        // Устанавливаем участников
        if isFromBalances {
            // Из балансов - используем переданных
            selectedPayer = payer
            selectedPayee = payee
            selectedCurrency = currency
            settlementAmount = String(format: "%.2f", amount)
        } else {
            // Из кнопки - выбираем первую валюту по умолчанию
            if selectedCurrency == nil, let firstCurrency = availableCurrencies.first {
                selectedCurrency = firstCurrency
            }
        }
        
        // Устанавливаем описание по умолчанию
        updateDescription()
    }
    
    private func updateDescription() {
        let payerName: String
        let payeeName: String
        
        if isFromBalances {
            payerName = payer?.name ?? "Unknown"
            payeeName = payee?.name ?? "Unknown"
        } else {
            payerName = selectedPayer?.name ?? "Unknown"
            payeeName = selectedPayee?.name ?? "Unknown"
        }
        
        settlementDescription = "\(localizationManager.localize(key: "Settlement")): \(payerName) → \(payeeName)"
    }
    
    private func isFormValid() -> Bool {
        let finalPayer = isFromBalances ? payer : selectedPayer
        let finalPayee = isFromBalances ? payee : selectedPayee
        let finalCurrency = isFromBalances ? currency : selectedCurrency
        
        guard finalPayer != nil,
              finalPayee != nil,
              finalCurrency != nil,
              let amountValue = Double(settlementAmount),
              amountValue > 0 else {
            return false
        }
        return true
    }
    
    private func saveSettlement() {
        let finalPayer = isFromBalances ? payer : selectedPayer
        let finalPayee = isFromBalances ? payee : selectedPayee
        let finalCurrency = isFromBalances ? currency : selectedCurrency
        
        guard let payer = finalPayer,
              let payee = finalPayee,
              let currency = finalCurrency,
              let amountValue = Double(settlementAmount),
              amountValue > 0 else { return }
        
        let expense = Expense(context: viewContext)
        expense.id = UUID()
        expense.desc = settlementDescription.isEmpty ? localizationManager.localize(key: "Settlement") : settlementDescription
        expense.amount = amountValue
        expense.currency = currency
        expense.is_settlement = true
        expense.isSoftDeleted = false
        expense.createdAt = settlementDate
        expense.updatedAt = Date()
        expense.paidBy = payer
        
        let share = ExpenseShare(context: viewContext)
        share.id = UUID()
        share.amount = amountValue
        share.participant = payee
        share.expense = expense
        
        expense.group = group
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving settlement: \(error)")
            viewContext.rollback()
        }
    }
}

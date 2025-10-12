import SwiftUI
import CoreData

struct SettleUpView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject private var localizationManager: LocalizationManager
    
    let group: Group
    let initialPayer: Participant?
    let initialPayee: Participant?
    let initialAmount: Double
    let initialCurrency: Currency?

    @State private var payer: Participant?
    @State private var payee: Participant?
    @State private var amount: Double = 0.0
    @State private var currency: Currency?

    @FetchRequest(
        entity: Currency.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Currency.currency_name, ascending: true)],
        predicate: NSPredicate(format: "is_active == YES")
    ) var currencies: FetchedResults<Currency>
    
    private var isFormValid: Bool {
        amount > 0 && payer != nil && payee != nil && payer != payee && currency != nil
    }

    init(group: Group, payer: Participant?, payee: Participant?, amount: Double, currency: Currency?) {
        self.group = group
        self.initialPayer = payer
        self.initialPayee = payee
        self.initialAmount = amount
        self.initialCurrency = currency
    }

    var body: some View {
        // Return the NavigationView to provide a context for the toolbar
        NavigationView {
            Form {
                Section(header: Text("Settlement details")) {
                    Picker("Paid by", selection: $payer) {
                        Text("Not selected").tag(nil as Participant?)
                        ForEach(group.membersArray, id: \.self) { participant in
                            Text(participant.name ?? "Unknown").tag(participant as Participant?)
                        }
                    }
                    
                    Picker("Payee", selection: $payee) {
                        Text("Not selected").tag(nil as Participant?)
                        ForEach(group.membersArray, id: \.self) { participant in
                            if participant != payer {
                                Text(participant.name ?? "Unknown").tag(participant as Participant?)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("Amount", value: $amount, format: .number.precision(.fractionLength(Int(currency?.decimal_digits ?? 2))))
                        #if os(iOS)
                            .keyboardType(.decimalPad)
                        #endif
                        Text(currency?.symbol_native ?? "")
                            .foregroundColor(.gray)
                    }
                    
                    Picker("Currency", selection: $currency) {
                        Text("Not selected").tag(nil as Currency?)
                        ForEach(currencies, id: \.self) { c in
                            Text("\(c.currency_name ?? "") (\(c.symbol_native ?? ""))").tag(c as Currency?)
                        }
                    }
                }
                
                // This clear section will act as a Spacer inside the Form
                Section {
                    Color.clear
                }
                .listRowBackground(Color.clear)
            }
            .onAppear(perform: setupInitialState)
            .navigationTitle("Debt repayment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePayment()
                        dismiss()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    private func setupInitialState() {
        payer = initialPayer
        payee = initialPayee
        amount = initialAmount
        
        if let initialCurrency = initialCurrency {
            currency = initialCurrency
        } else {
            currency = group.defaultCurrency
        }
    }
    
    private func savePayment() {
        guard let payer = payer,
              let payee = payee,
              let currency = currency,
              let userID = authService.currentUser?.id,
              amount > 0 else { return }

        let newPayment = Expense(context: viewContext)
        newPayment.id = UUID()
        newPayment.is_settlement = true
        newPayment.amount = amount
        newPayment.desc = "\(payer.name ?? "") → \(payee.name ?? "")"
        
        // --- Audit Fields ---
        let now = Date()
        newPayment.createdAt = now // CORRECTED from .date
        newPayment.createdBy = Int64(userID)
        newPayment.updatedAt = now
        newPayment.updatedBy = Int64(userID)
        // --------------------
        
        newPayment.needsSync = true
        newPayment.group = group
        newPayment.currency = currency
        newPayment.paidBy = payer
        
        let share = ExpenseShare(context: viewContext)
        share.id = UUID()
        share.participant = payee
        share.amount = amount
        
        newPayment.addToShares(share)
        
        try? viewContext.save()
    }
}

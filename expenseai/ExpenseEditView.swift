import SwiftUI
import CoreData

enum DistributionType: String, CaseIterable, Identifiable {
    case equally = "Поровну"
    case parts = "По частям"
    case percentage = "По процентам"
    case manually = "Вручную"

    var id: String { self.rawValue }
}

struct ExpenseEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService

    // General state
    @State private var amount: Double = 0
    @State private var descriptionText = ""
    @State private var selectedPayer: Participant?
    @State private var selectedGroup: Group?
    @State private var selectedCurrency: Currency?
    @State private var participants: Set<Participant> = []
    @State private var showingParticipantSelector = false
    @State private var showingDeleteAlert = false
    
    // Distribution state
    @State private var distributionType: DistributionType = .equally
    @State private var shares: [Participant: Double] = [:]
    @State private var shareParts: [Participant: Double] = [:]
    @State private var sharePercentages: [Participant: Double] = [:]
    
    @State private var expenseToEdit: Expense?
    @State private var groupForNewExpense: Group?
    
    @FetchRequest(
        entity: Currency.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Currency.currency_name, ascending: true)],
        predicate: NSPredicate(format: "is_active == YES")
    ) var currencies: FetchedResults<Currency>
    
    var navigationTitle: String { expenseToEdit == nil ? "Новые затраты" : "Редактировать затраты" }
    var sortedParticipants: [Participant] { participants.sorted { $0.name ?? "" < $1.name ?? "" } }
    
    // Validation
    var totalParts: Double { shareParts.values.reduce(0, +) }
    var totalPercentage: Double { sharePercentages.values.reduce(0, +) }
    var totalManualAmount: Double { shares.values.reduce(0, +) }

    init(expense: Expense? = nil, group: Group? = nil) {
        _expenseToEdit = State(initialValue: expense)
        _groupForNewExpense = State(initialValue: group)
    }

    var body: some View {
        NavigationView {
            Form {
                basicInfoSection
                groupAndPayerSection
                participantsSection
                distributionMethodSection
                distributionDetailsSection
                
                if expenseToEdit != nil {
                    Section {
                        Button("Удалить затрату", role: .destructive) {
                            showingDeleteAlert = true
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save(); dismiss() }
                        .disabled(isSaveDisabled)
                }
            }
            .sheet(isPresented: $showingParticipantSelector) {
                NavigationView {
                    MultiSelectParticipantView(allParticipants: selectedGroup?.membersArray ?? [], selectedParticipants: $participants)
                }
            }
            .alert("Удалить затрату?", isPresented: $showingDeleteAlert) {
                Button("Удалить", role: .destructive) {
                    deleteExpense()
                    dismiss()
                }
                Button("Отмена", role: .cancel) { }
            } message: {
                Text("Вы уверены, что хотите удалить эту затрату? Это действие нельзя отменить.")
            }
            .onAppear(perform: setupInitialState)
            .onChange(of: amount) { recalculateShares() }
            .onChange(of: participants) { recalculateShares() }
            .onChange(of: distributionType) {
                shareParts.removeAll()
                sharePercentages.removeAll()
                recalculateShares()
            }
            .onChange(of: shareParts) { recalculateShares() }
            .onChange(of: sharePercentages) { recalculateShares() }
        }
    }
    
    // MARK: - Form Sections (Refactored)
    
    @ViewBuilder
    private var basicInfoSection: some View {
        Section {
            HStack {
                TextField("Сумма", value: $amount, format: .number.precision(.fractionLength(Int(selectedCurrency?.decimal_digits ?? 2))))
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Text(selectedCurrency?.symbol_native ?? "")
                    .foregroundColor(.gray)
            }
            TextField("Описание", text: $descriptionText)
        }
    }
    
    @ViewBuilder
    private var groupAndPayerSection: some View {
        Section {
            HStack {
                Text("Группа")
                Spacer()
                Text(selectedGroup?.name ?? "Не выбрана").foregroundColor(.gray)
            }
            Picker("Валюта", selection: $selectedCurrency) {
                Text("Не выбрана").tag(nil as Currency?)
                ForEach(currencies, id: \.self) { currency in
                    Text("\(currency.currency_name ?? "") (\(currency.symbol_native ?? ""))").tag(currency as Currency?)
                }
            }
            .disabled(selectedGroup == nil)
            
            Picker("Оплатил", selection: $selectedPayer) {
                Text("Не выбран").tag(nil as Participant?)
                ForEach(selectedGroup?.membersArray ?? [], id: \.self) { participant in
                    Text(participant.name ?? "Unknown").tag(participant as Participant?)
                }
            }
            .disabled(selectedGroup == nil)
        }
    }
    
    @ViewBuilder
    private var participantsSection: some View {
        if selectedGroup != nil {
            Section {
                Button(action: { showingParticipantSelector = true }) {
                    HStack {
                        Text("Участники")
                        Spacer()
                        Text("\(participants.count) выбрано").foregroundColor(.gray)
                    }
                }
                .foregroundColor(.primary)
            }
        }
    }
    
    @ViewBuilder
    private var distributionMethodSection: some View {
        Section(header: Text("Метод распределения")) {
            Picker("Метод", selection: $distributionType) {
                ForEach(DistributionType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    @ViewBuilder
    private var distributionDetailsSection: some View {
        if !participants.isEmpty {
            Section(header: Text("Распределение затрат"), footer: distributionFooter) {
                ForEach(sortedParticipants, id: \.id) { participant in
                    distributionRow(for: participant)
                }
            }
        }
    }

    // MARK: - Subviews
    @ViewBuilder
    private func distributionRow(for participant: Participant) -> some View {
        HStack {
            Text(participant.name ?? "Unknown")
            Spacer()
            
            switch distributionType {
            case .equally:
                Text(shares[participant] ?? 0, format: .number.precision(.fractionLength(2)))
                    .foregroundColor(.gray)
            case .parts:
                Text(shares[participant] ?? 0, format: .number.precision(.fractionLength(2)))
                    .foregroundColor(.gray)
                    .frame(minWidth: 60, alignment: .trailing)

                TextField("Части", value: Binding(get: { shareParts[participant] ?? 1.0 }, set: { shareParts[participant] = $0 }), format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            case .percentage:
                Text(shares[participant] ?? 0, format: .number.precision(.fractionLength(2)))
                    .foregroundColor(.gray)
                    .frame(minWidth: 60, alignment: .trailing)
                
                TextField("Процент", value: Binding(get: { sharePercentages[participant] ?? 0.0 }, set: { sharePercentages[participant] = $0 }), format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .overlay(Text("%").foregroundColor(.gray).padding(.leading), alignment: .trailing)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            case .manually:
                TextField("Сумма", value: Binding(get: { shares[participant] ?? 0.0 }, set: { shares[participant] = $0 }), format: .number.precision(.fractionLength(2)))
                    .multilineTextAlignment(.trailing)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }
        }
    }
    
    @ViewBuilder
    private var distributionFooter: some View {
        switch distributionType {
        case .parts:
            Text("Всего частей: \(totalParts, format: .number)")
        case .percentage:
            let color = totalPercentage == 100.0 ? Color.green : Color.red
            Text("Всего: \(totalPercentage, format: .number) %")
                .foregroundColor(color)
        case .manually:
            let total = totalManualAmount
            let remaining = amount - total
            let color = abs(remaining) < 0.01 ? Color.green : Color.red
            VStack(alignment: .leading) {
                Text("Введено: \(total, format: .number.precision(.fractionLength(2)))")
                Text("Осталось: \(remaining, format: .number.precision(.fractionLength(2)))")
            }.foregroundColor(color)
        default:
            EmptyView()
        }
    }
    
    // MARK: - Logic
    
    private func deleteExpense() {
        guard let expense = expenseToEdit, let userID = authService.currentUser?.id else { return }
        expense.isSoftDeleted = true
        expense.updatedAt = Date()
        expense.updatedBy = Int64(userID)
        expense.needsSync = true
        try? viewContext.save()
    }
    
    private func setupInitialState() {
        if let expense = expenseToEdit {
            amount = expense.amount
            descriptionText = expense.desc ?? ""
            selectedPayer = expense.paidBy
            selectedGroup = expense.group
            selectedCurrency = expense.currency
            
            var initialParticipants: Set<Participant> = []
            for share in expense.sharesArray {
                if let participant = share.participant {
                    initialParticipants.insert(participant)
                    shares[participant] = share.amount
                }
            }
            participants = initialParticipants
            distributionType = .manually
            
        } else if let group = groupForNewExpense {
            selectedGroup = group
            selectedCurrency = group.defaultCurrency
            participants = Set(group.membersArray)
            recalculateShares()
        }
    }

    private var isSaveDisabled: Bool {
        guard amount > 0, selectedPayer != nil, !participants.isEmpty else { return true }
        switch distributionType {
        case .percentage: return totalPercentage != 100.0
        case .manually: return abs(amount - totalManualAmount) > 0.01
        default: return false
        }
    }

    private func recalculateShares() {
        guard !participants.isEmpty else {
            shares.removeAll(); return
        }
        
        var calculatedShares: [Participant: Double] = [:]
        
        switch distributionType {
        case .equally:
            guard amount > 0 else { return }
            let shareAmount = (amount / Double(participants.count) * 100).rounded() / 100
            for participant in participants { calculatedShares[participant] = shareAmount }

        case .parts:
            guard amount > 0, totalParts > 0 else { return }
            let valuePerPart = amount / totalParts
            for participant in participants {
                calculatedShares[participant] = (shareParts[participant] ?? 0) * valuePerPart
            }
            
        case .percentage:
            guard amount > 0 else { return }
            for participant in participants {
                calculatedShares[participant] = amount * ((sharePercentages[participant] ?? 0) / 100.0)
            }
            
        case .manually:
            let oldShares = shares
            var newShares: [Participant: Double] = [:]
            for participant in participants {
                newShares[participant] = oldShares[participant] ?? 0.0
            }
            calculatedShares = newShares
        }
        
        shares = calculatedShares
    }

    private func save() {
        guard !isSaveDisabled, let userID = authService.currentUser?.id else { return }
        
        if distributionType != .manually {
            recalculateShares()
        }

        let isNew = expenseToEdit == nil
        let expenseToSave = expenseToEdit ?? Expense(context: viewContext)
        
        if isNew {
            expenseToSave.id = UUID()
            expenseToSave.createdAt = Date() // Was 'date'
            expenseToSave.createdBy = Int64(userID)
        }
        
        expenseToSave.amount = amount
        expenseToSave.desc = descriptionText
        expenseToSave.paidBy = selectedPayer
        expenseToSave.group = selectedGroup
        expenseToSave.currency = selectedCurrency
        
        // Always update audit fields
        expenseToSave.updatedAt = Date()
        expenseToSave.updatedBy = Int64(userID)
        expenseToSave.needsSync = true

        if let oldShares = expenseToSave.shares as? Set<ExpenseShare> {
            for share in oldShares { viewContext.delete(share) }
        }
        
        for participant in participants {
            let shareAmount = shares[participant] ?? 0.0
            let newShare = ExpenseShare(context: viewContext)
            newShare.id = UUID()
            newShare.participant = participant
            newShare.amount = shareAmount
            expenseToSave.addToShares(newShare)
        }

        try? viewContext.save()
    }
}

// MARK: - Helper Views

struct MultiSelectParticipantView: View {
    let allParticipants: [Participant]
    @Binding var selectedParticipants: Set<Participant>
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(allParticipants, id: \.id) { participant in
                Button(action: {
                    if selectedParticipants.contains(participant) {
                        selectedParticipants.remove(participant)
                    } else {
                        selectedParticipants.insert(participant)
                    }
                }) {
                    HStack {
                        Text(participant.name ?? "Unknown")
                        Spacer()
                        if selectedParticipants.contains(participant) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle("Выберите участников")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Готово") {
                    dismiss()
                }
            }
        }
    }
}
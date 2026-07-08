import SwiftUI
import CoreData

struct GroupEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject private var localizationManager: LocalizationManager

    let group: Group?
    
    @State private var name: String = ""
    @State private var selectedCurrency: Currency?
    @State private var selectedParticipants: Set<Participant> = []
    
    @State private var showingValidationAlert = false
    @State private var isInitialized = false

    private var pickerCurrencies: [Currency] {
        var availableCurrencies = Array(currencies)
        if let groupCurrency = group?.defaultCurrency, !availableCurrencies.contains(groupCurrency) {
            availableCurrencies.insert(groupCurrency, at: 0)
        }
        return availableCurrencies
    }

    private var isNew: Bool {
        group == nil
    }
    
    var navigationTitle: String {
        isNew ? localizationManager.localize(key: "New group") : localizationManager.localize(key: "Edit group")
    }

    @FetchRequest(
        entity: Participant.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Participant.name, ascending: true)],
        predicate: NSPredicate(format: "isSoftDeleted == NO")
    ) var activeParticipants: FetchedResults<Participant>
    
    // --- ИЗМЕНЕНО: Используем first_name и last_name ---
    private var currentUserParticipant: Participant? {
        guard let currentUser = authService.currentUser else { return nil }
        return activeParticipants.first { participant in
            guard let participantEmail = participant.email else { return false }
            return participantEmail.caseInsensitiveCompare(currentUser.email) == .orderedSame
        }
    }
    
    private var displayParticipants: [Participant] {
        var result = Set(activeParticipants)
        
        for participant in selectedParticipants {
            if participant.isSoftDeleted {
                result.insert(participant)
            }
        }
        
        return result.sorted {
            let name1 = $0.name ?? ""
            let name2 = $1.name ?? ""
            return name1 < name2
        }
    }
    
    @FetchRequest(
        entity: Currency.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Currency.currency_name, ascending: true)],
        predicate: NSPredicate(format: "is_active == YES")
    ) var currencies: FetchedResults<Currency>
    
    init(group: Group? = nil) {
        self.group = group
        _name = State(initialValue: group?.name ?? "")
        _selectedCurrency = State(initialValue: group?.defaultCurrency)
        _selectedParticipants = State(initialValue: group?.members as? Set<Participant> ?? [])
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(localizationManager.localize(key: "General"))) {
                    TextField(localizationManager.localize(key: "Group title"), text: $name)
                    Picker(localizationManager.localize(key: "Default currency"), selection: $selectedCurrency) {
                        Text(localizationManager.localize(key: "Not selected")).tag(nil as Currency?)
                        ForEach(pickerCurrencies, id: \.self) { currency in
                            Text("\(currency.currency_name ?? "") (\(currency.symbol_native ?? ""))").tag(currency as Currency?)
                        }
                    }
                }
                
                Section {
                    let availableParticipants = displayParticipants
                    
                    if availableParticipants.isEmpty {
                        Text(localizationManager.localize(key: "No available participants"))
                            .foregroundColor(.gray)
                    } else {
                        ForEach(availableParticipants, id: \.id) { participant in
                            let isCurrentUser = isParticipantCurrentUser(participant)
                            let isSelected = selectedParticipants.contains(participant)
                            let isDisabled = participant.isSoftDeleted || isCurrentUser
                            
                            Button(action: {
                                guard !isCurrentUser else { return }
                                
                                if isSelected {
                                    selectedParticipants.remove(participant)
                                } else {
                                    selectedParticipants.insert(participant)
                                }
                            }) {
                                HStack {
                                    // --- ИЗМЕНЕНО: Отображение имени ---
                                    if participant.isSoftDeleted {
                                        Text(participant.name ?? "Unknown")
                                            .foregroundColor(.gray)
                                        Text("(deleted)")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    } else if isCurrentUser {
                                        Text(participant.name ?? "Unknown")
                                        Text("(current user)")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else {
                                        Text(participant.name ?? "Unknown")
                                    }
                                    
                                    Spacer()
                                    
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(isDisabled ? .gray : .accentColor)
                                    }
                                }
                            }
                            .foregroundColor(participant.isSoftDeleted ? .gray : .primary)
                            .disabled(isDisabled)
                        }
                    }
                } header: {
                    HStack {
                        Text(localizationManager.localize(key: "Participants"))
                        Spacer()
                        NavigationLink(destination: ParticipantsListView()) {
                            Image(systemName: "person.2.badge.plus")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localize(key: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localize(key: "Save")) {
                        validateAndSave()
                    }
                }
            }
            .onAppear {
                if isNew && selectedCurrency == nil {
                    selectedCurrency = currencies.first
                }
                initializeCurrentUserParticipant()
            }
            .alert(localizationManager.localize(key: "Incomplete data"), isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(localizationManager.localize(key: "Please fill in the name, select a currency and participants for the group."))
            }
        }
    }
    
    // --- ИЗМЕНЕНО: Проверка по email ---
    private func isParticipantCurrentUser(_ participant: Participant) -> Bool {
        guard let participantEmail = participant.email,
              let currentUserEmail = authService.currentUser?.email,
              !participantEmail.isEmpty else {
            return false
        }
        return participantEmail.caseInsensitiveCompare(currentUserEmail) == .orderedSame
    }
    
    // --- ИЗМЕНЕНО: Создание участника с first_name и last_name ---
    private func createCurrentUserParticipant() {
        guard let currentUser = authService.currentUser else { return }
        
        let newParticipant = Participant(context: viewContext)
        newParticipant.id = UUID()
        
        // Объединяем first_name и last_name в name
        let fullName = [currentUser.first_name, currentUser.last_name]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        newParticipant.name = fullName.isEmpty ? currentUser.email : fullName
        
        newParticipant.email = currentUser.email
        newParticipant.isSoftDeleted = false
        newParticipant.needsSync = true
        
        do {
            try viewContext.save()
            // После сохранения добавляем в выбранные
            if let createdParticipant = currentUserParticipant {
                selectedParticipants.insert(createdParticipant)
                isInitialized = true
            }
        } catch {
            print("Failed to create participant: \(error)")
        }
    }
    
    private func initializeCurrentUserParticipant() {
        guard isNew, !isInitialized else { return }
        
        if let currentParticipant = currentUserParticipant {
            selectedParticipants.insert(currentParticipant)
            isInitialized = true
        } else {
            // Если участник не найден, создаем его
            createCurrentUserParticipant()
        }
    }
    
    private func validateAndSave() {
        let isNameValid = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isCurrencyValid = selectedCurrency != nil
        let areParticipantsValid = !selectedParticipants.isEmpty

        if isNameValid && isCurrencyValid && areParticipantsValid {
            save()
            dismiss()
        } else {
            showingValidationAlert = true
        }
    }
    
    private func save() {
        guard let userID = authService.currentUser?.id else {
            print("Error: Could not find logged in user ID.")
            return
        }
        
        let groupToSave = group ?? Group(context: viewContext)
        
        if isNew {
            groupToSave.id = UUID()
            groupToSave.createdAt = Date()
            groupToSave.updatedAt = Date()
            groupToSave.createdBy = Int64(userID)
        }
        
        groupToSave.name = name
        groupToSave.defaultCurrency = selectedCurrency
        groupToSave.members = selectedParticipants as NSSet
        
        for participant in selectedParticipants {
            participant.needsSync = true
        }
        
        groupToSave.updatedAt = Date()
        groupToSave.updatedBy = Int64(userID)
        groupToSave.needsSync = true
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

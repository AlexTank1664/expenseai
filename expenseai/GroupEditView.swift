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

    private var pickerCurrencies: [Currency] {
        // Начинаем с массива активных валют
        var availableCurrencies = Array(currencies)

        // Проверяем, есть ли у группы сохраненная валюта
        // и не содержится ли она уже в списке активных
        if let groupCurrency = group?.defaultCurrency, !availableCurrencies.contains(groupCurrency) {
            // Если ее нет, добавляем ее в начало списка
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

    // --- Fetched data for pickers ---
    @FetchRequest(
        entity: Participant.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Participant.name, ascending: true)]
    ) var participants: FetchedResults<Participant>
    
    @FetchRequest(
        entity: Currency.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Currency.currency_name, ascending: true)],
        predicate: NSPredicate(format: "is_active == YES")
    ) var currencies: FetchedResults<Currency>
    
    // --- Initializer ---
    init(group: Group? = nil) {
        self.group = group
        // Initialize state based on whether we are editing or creating
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
                    if participants.isEmpty {
                        Text(localizationManager.localize(key: "Choose participants"))
                            .foregroundColor(.gray)
                    } else {
                        ForEach(participants, id: \.id) { participant in
                            Button(action: {
                                if selectedParticipants.contains(participant) {
                                    selectedParticipants.remove(participant)
                                } else {
                                    selectedParticipants.insert(participant)
                                }
                            }) {
                                HStack {
                                    Text(participant.name ?? "Unknown")
                                    if participant.isSoftDeleted {
                                        Text("(deleted)")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    if selectedParticipants.contains(participant) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                } header: {
                    HStack {
                        Text(localizationManager.localize(key: "Participants"))
                        Spacer()
                        NavigationLink(destination: ParticipantsListView()) {
                            HStack(spacing: 4) {

//                                Text(localizationManager.localize(key: "Manage"))
//                                    .font(.subheadline)
                                Image(systemName: "person.2.badge.plus")
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                }
                // -------------------------------------
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
            }
            .alert(localizationManager.localize(key: "Incomplete data"), isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(localizationManager.localize(key: "Please fill in the name, select a currency and participants for the group."))
            }
        }
    }
    
    // --- НАЧАЛО ИЗМЕНЕНИЙ 4: Новая функция для валидации ---
    private func validateAndSave() {
        // Проверяем, что имя не пустое (после удаления пробелов),
        // валюта выбрана и есть хотя бы один участник.
        let isNameValid = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isCurrencyValid = selectedCurrency != nil
        let areParticipantsValid = !selectedParticipants.isEmpty

        if isNameValid && isCurrencyValid && areParticipantsValid {
            // Если все в порядке - сохраняем и закрываем
            save()
            dismiss()
        } else {
            // Если есть ошибки - показываем алерт
            showingValidationAlert = true
        }
    }
    // --- КОНЕЦ ИЗМЕНЕНИЙ 4 ---
    
    private func save() {
        guard let userID = authService.currentUser?.id else {
            print("Error: Could not find logged in user ID.")
            return
        }
        
        // Use the existing group or create a new one
        let groupToSave = group ?? Group(context: viewContext)
        
        // If it's a new group, set its ID and creation audit fields
        if isNew {
            groupToSave.id = UUID()
            groupToSave.createdAt = Date()
            groupToSave.updatedAt = Date()
            groupToSave.createdBy = Int64(userID)
        }
        
        // Update properties from local state
        groupToSave.name = name
        groupToSave.defaultCurrency = selectedCurrency
        groupToSave.members = selectedParticipants as NSSet
        
        // --- НАЧАЛО ИЗМЕНЕНИЙ ---
        // Теперь мы помечаем всех участников этой группы для синхронизации.
        // Это гарантирует, что они будут отправлены на сервер вместе с группой.
        for participant in selectedParticipants {
            participant.needsSync = true
        }
        // --- КОНЕЦ ИЗМЕНЕНИЙ ---
        
        // Always update the modification audit fields
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

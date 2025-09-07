import SwiftUI
import CoreData

struct GroupEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // The group to edit, if it exists. Nil if we are creating a new one.
    let group: Group?
    
    // --- Local state for the form ---
    @State private var name: String = ""
    @State private var selectedCurrency: Currency?
    @State private var selectedParticipants: Set<Participant> = []
  //  NSLocalizedString(   , comment: "")
    // Computed properties
    private var isNew: Bool {
        group == nil
    }
    
    var navigationTitle: String {
        isNew ? NSLocalizedString(  "New group" , comment: "") : NSLocalizedString( "Edit group"  , comment: "")
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
                Section(header: Text(NSLocalizedString( "Basic information"  , comment: ""))) {
                    TextField(NSLocalizedString( "Group name"  , comment: ""), text: $name)
                    Picker(NSLocalizedString( "Default currency"  , comment: ""), selection: $selectedCurrency) {
                        Text(NSLocalizedString(  "Not selected" , comment: "")).tag(nil as Currency?)
                        ForEach(currencies, id: \.self) { currency in
                            Text("\(currency.currency_name ?? "") (\(currency.symbol_native ?? ""))").tag(currency as Currency?)
                        }
                    }
                }

                Section(header: Text(NSLocalizedString(  "Participants" , comment: ""))) {
                    if participants.isEmpty {
                        Text(NSLocalizedString( "Add participants first"  , comment: ""))
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
                                    Spacer()
                                    if selectedParticipants.contains(participant) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString(  "Отмена" , comment: "")) {
                        
                        dismiss() // Just dismiss, no need to delete anything
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString(  "Сохранить" , comment: "")) {
                        save()
                        dismiss()
                    }
                    .disabled(name.isEmpty || selectedParticipants.isEmpty)
                }
            }
            .onAppear {
                // Set default currency only if creating a new group
                if isNew && selectedCurrency == nil {
                    selectedCurrency = currencies.first
                }
            }
        }
    }
    
    private func save() {
        // Use the existing group or create a new one
        let groupToSave = group ?? Group(context: viewContext)
        
        // If it's a new group, set its ID
        if isNew {
            groupToSave.id = UUID()
        }
        
        // Update properties from local state
        groupToSave.name = name
        groupToSave.defaultCurrency = selectedCurrency
        groupToSave.members = selectedParticipants as NSSet
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

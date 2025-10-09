import SwiftUI
import CoreData

struct ManageCurrenciesView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: Currency.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Currency.currency_name, ascending: true)]
    ) var allCurrencies: FetchedResults<Currency>

    var body: some View {
        Form {
            Section(header: Text("Select сurrencies")) {
                ForEach(allCurrencies, id: \.self) { currency in
                    Toggle(isOn: Binding(
                        get: { currency.is_active },
                        set: { newValue in
                            currency.is_active = newValue
                            try? viewContext.save()
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text(currency.currency_name ?? "Unknown")
                            Text(currency.c_code ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Active currencies")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

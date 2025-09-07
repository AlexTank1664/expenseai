import SwiftUI
import CoreData

struct CurrenciesListView: View {
    @FetchRequest(
        entity: Currency.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Currency.c_code, ascending: true)]
    ) var currencies: FetchedResults<Currency>

    var body: some View {
        List {
            ForEach(currencies, id: \.self) { currency in
                HStack {
                    Text(currency.c_code ?? "N/A")
                        .font(.headline)
                        .frame(width: 60, alignment: .leading)
                    VStack(alignment: .leading) {
                        Text(currency.currency_name ?? "Unknown")
                        Text(currency.currency_name_plural ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(currency.symbol_native ?? "")
                        .font(.title3)
                }
            }
        }
        .navigationTitle("Валюты")
    }
}
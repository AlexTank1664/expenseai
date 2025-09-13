//
//  codedta.swift
//  expenseai
//
//  Created by MacbookPro on 18.08.2025.
//
import Foundation
import CoreData

class DataController: ObservableObject {
    static let shared = DataController()
    
    let container: NSPersistentContainer
    

    
    init(inMemory: Bool = false) {
        // Убедитесь, что "Model" - это правильное имя вашего .xcdatamodeld файла
        container = NSPersistentContainer(name: "Model")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
            
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
            
            // Запускаем заполнение базы данных валютами после загрузки
            self.seedCurrenciesIfNeeded()
        }
        print(container.persistentStoreDescriptions.first?.url as Any)
    }
    
    private func seedCurrenciesIfNeeded() {
        let context = container.viewContext
        
        let fetchRequest: NSFetchRequest<Currency> = Currency.fetchRequest()
        
        do {
            let count = try context.count(for: fetchRequest)
            // Если валюты в базе уже есть, ничего не делаем
            guard count == 0 else {
                print("✅ Currencies already seeded.")
                return
            }
            
            // Вспомогательная функция для удобного создания валют
            let createCurrency: (String, String, Int16, String, Int16, Double, String, String) -> Void = {
                c_code, currency_name, i_code, currency_name_plural, decimal_digits, rounding, symbol, symbol_native in
                
                let currency = Currency(context: context)
                currency.c_code = c_code
                currency.currency_name = currency_name
                currency.i_code = i_code
                currency.currency_name_plural = currency_name_plural
                currency.decimal_digits = decimal_digits
                currency.rounding = rounding
                currency.symbol = symbol
                currency.symbol_native = symbol_native
                // Активируем только RUB и USD по умолчанию
                currency.is_active = (c_code == "RUB" || c_code == "USD")
            }

            // Заполнение валют из предоставленного списка
            createCurrency("CAD", "Canadian Dollar", 0, "Canadian dollars", 2, 0, "CA$", "$")
            createCurrency("EUR", "Euro", 0, "euros", 2, 0, "€", "€")
            createCurrency("AED", "United Arab Emirates Dirham", 0, "UAE dirhams", 2, 0, "AED", "د.إ.‏")
            createCurrency("AFN", "Afghan Afghani", 0, "Afghan Afghanis", 0, 0, "Af", "؋")
            createCurrency("ALL", "Albanian Lek", 0, "Albanian lekë", 0, 0, "ALL", "Lek")
            createCurrency("AMD", "Armenian Dram", 0, "Armenian drams", 0, 0, "AMD", "դր.")
            createCurrency("ANG", "Netherlands Antillean guilder", 0, "Netherlands Antillean guilder", 0, 0, "ƒ", "ƒ")
            createCurrency("AOA", "Angolan Kwanza", 0, "Angolan Kwanzas", 0, 0, "Kz", "Kz")
            createCurrency("ARS", "Argentine Peso", 0, "Argentine pesos", 2, 0, "AR$", "$")
            createCurrency("AUD", "Australian Dollar", 0, "Australian dollars", 2, 0, "AU$", "$")
            createCurrency("AZN", "Azerbaijani Manat", 0, "Azerbaijani manats", 2, 0, "man.", "ман.")
            createCurrency("BAM", "Bosnia-Herzegovina Convertible Mark", 0, "Bosnia-Herzegovina convertible marks", 2, 0, "KM", "KM")
            createCurrency("BDT", "Bangladeshi Taka", 0, "Bangladeshi takas", 2, 0, "Tk", "৳")
            createCurrency("BGN", "Bulgarian Lev", 0, "Bulgarian leva", 2, 0, "BGN", "лв.")
            createCurrency("BHD", "Bahraini Dinar", 0, "Bahraini dinars", 3, 0, "BD", "د.ب.‏")
            createCurrency("BIF", "Burundian Franc", 0, "Burundian francs", 0, 0, "FBu", "FBu")
            createCurrency("BND", "Brunei Dollar", 0, "Brunei dollars", 2, 0, "BN$", "$")
            createCurrency("BMD", "Bermudian Dollar", 0, "Bermudian Dollar", 2, 0, "$", "$")
            createCurrency("BOB", "Bolivian Boliviano", 0, "Bolivian bolivianos", 2, 0, "Bs", "Bs")
            createCurrency("BRL", "Brazilian Real", 0, "Brazilian reals", 2, 0, "R$", "R$")
            createCurrency("BTN", "Bhutanese Ngultrum", 0, "Bhutanese Ngultrum", 2, 0, "Nu.", "Nu.")
            createCurrency("BWP", "Botswanan Pula", 0, "Botswanan pulas", 2, 0, "BWP", "P")
            createCurrency("BYR", "Belarusian Ruble", 0, "Belarusian rubles", 0, 0, "BYR", "BYR")
            createCurrency("BZD", "Belize Dollar", 0, "Belize dollars", 2, 0, "BZ$", "$")
            createCurrency("CDF", "Congolese Franc", 0, "Congolese francs", 2, 0, "CDF", "FrCD")
            createCurrency("CHF", "Swiss Franc", 0, "Swiss francs", 2, 0.05, "CHF", "CHF")
            createCurrency("CLP", "Chilean Peso", 0, "Chilean pesos", 0, 0, "CL$", "$")
            createCurrency("CNY", "Chinese Yuan", 0, "Chinese yuan", 2, 0, "CN¥", "CN¥")
            createCurrency("COP", "Colombian Peso", 0, "Colombian pesos", 0, 0, "CO$", "$")
            createCurrency("CRC", "Costa Rican Colón", 0, "Costa Rican colóns", 0, 0, "₡", "₡")
            createCurrency("CVE", "Cape Verdean Escudo", 0, "Cape Verdean escudos", 2, 0, "CV$", "CV$")
            createCurrency("CZK", "Czech Republic Koruna", 0, "Czech Republic korunas", 2, 0, "Kč", "Kč")
            createCurrency("DJF", "Djiboutian Franc", 0, "Djiboutian francs", 0, 0, "Fdj", "Fdj")
            createCurrency("DKK", "Danish Krone", 0, "Danish kroner", 2, 0, "Dkr", "kr")
            createCurrency("DOP", "Dominican Peso", 0, "Dominican pesos", 2, 0, "RD$", "RD$")
            createCurrency("DZD", "Algerian Dinar", 0, "Algerian dinars", 2, 0, "DA", "د.ج.‏")
            createCurrency("EEK", "Estonian Kroon", 0, "Estonian kroons", 2, 0, "Ekr", "kr")
            createCurrency("EGP", "Egyptian Pound", 0, "Egyptian pounds", 2, 0, "EGP", "ج.م.‏")
            createCurrency("ERN", "Eritrean Nakfa", 0, "Eritrean nakfas", 2, 0, "Nfk", "Nfk")
            createCurrency("ETB", "Ethiopian Birr", 0, "Ethiopian birrs", 2, 0, "Br", "Br")
            createCurrency("FKP", "Falkland Island Pound", 0, "Falkland Island Pounds", 2, 0, "£", "£")
            createCurrency("GBP", "British Pound Sterling", 0, "British pounds sterling", 2, 0, "£", "£")
            createCurrency("GEL", "Georgian Lari", 0, "Georgian laris", 2, 0, "GEL", "GEL")
            createCurrency("GHS", "Ghanaian Cedi", 0, "Ghanaian cedis", 2, 0, "GH₵", "GH₵")
            createCurrency("GIP", "Gibraltar Pound", 0, "Gibraltar pound", 2, 0, "£", "£")
            createCurrency("GNF", "Guinean Franc", 0, "Guinean francs", 0, 0, "FG", "FG")
            createCurrency("GTQ", "Guatemalan Quetzal", 0, "Guatemalan quetzals", 2, 0, "GTQ", "Q")
            createCurrency("HKD", "Hong Kong Dollar", 0, "Hong Kong dollars", 2, 0, "HK$", "$")
            createCurrency("HNL", "Honduran Lempira", 0, "Honduran lempiras", 2, 0, "HNL", "L")
            createCurrency("HRK", "Croatian Kuna", 0, "Croatian kunas", 2, 0, "kn", "kn")
            createCurrency("HUF", "Hungarian Forint", 0, "Hungarian forints", 0, 0, "Ft", "Ft")
            createCurrency("IDR", "Indonesian Rupiah", 0, "Indonesian rupiahs", 0, 0, "Rp", "Rp")
            createCurrency("ILS", "Israeli New Sheqel", 0, "Israeli new sheqels", 2, 0, "₪", "₪")
            createCurrency("INR", "Indian Rupee", 0, "Indian rupees", 2, 0, "Rs", "₹")
            createCurrency("IQD", "Iraqi Dinar", 0, "Iraqi dinars", 0, 0, "IQD", "د.ع.‏")
            createCurrency("IRR", "Iranian Rial", 0, "Iranian rials", 0, 0, "IRR", "﷼")
            createCurrency("ISK", "Icelandic Króna", 0, "Icelandic krónur", 0, 0, "Ikr", "kr")
            createCurrency("JMD", "Jamaican Dollar", 0, "Jamaican dollars", 2, 0, "J$", "$")
            createCurrency("JOD", "Jordanian Dinar", 0, "Jordanian dinars", 3, 0, "JD", "د.أ.‏")
            createCurrency("JPY", "Japanese Yen", 0, "Japanese yen", 0, 0, "¥", "￥")
            createCurrency("KES", "Kyrgyzstani som", 0, "Kyrgyzstani som", 2, 0, "с", "с")
            createCurrency("KGS", "Kyrgyzstani Som", 0, "Kenyan shillings", 2, 0, "Ksh", "Ksh")
            createCurrency("KHR", "Cambodian Riel", 0, "Cambodian riels", 2, 0, "KHR", "៛")
            createCurrency("KMF", "Comorian Franc", 0, "Comorian francs", 0, 0, "CF", "FC")
            createCurrency("KRW", "South Korean Won", 0, "South Korean won", 0, 0, "₩", "₩")
            createCurrency("KWD", "Kuwaiti Dinar", 0, "Kuwaiti dinars", 3, 0, "KD", "د.ك.‏")
            createCurrency("KYD", "Cayman Islands dollar", 0, "Cayman Islands dollarS", 2, 0, "$", "$‏")
            createCurrency("KZT", "Kazakhstani Tenge", 0, "Kazakhstani tenges", 2, 0, "KZT", "тңг.")
            createCurrency("LAK", "Lao kip", 0, "Lao kip", 0, 0, "₭", "₭‏")
            createCurrency("LBP", "Lebanese Pound", 0, "Lebanese pounds", 0, 0, "LB£", "ل.ل.‏")
            createCurrency("LKR", "Sri Lankan Rupee", 0, "Sri Lankan rupees", 2, 0, "SLRs", "SL Re")
            createCurrency("LRD", "Liberian Dollar", 0, "Liberian Dollars", 2, 0, "$", "$")
            createCurrency("LTL", "Lithuanian Litas", 0, "Lithuanian litai", 2, 0, "Lt", "Lt")
            createCurrency("LVL", "Latvian Lats", 0, "Latvian lati", 2, 0, "Ls", "Ls")
            createCurrency("LYD", "Libyan Dinar", 0, "Libyan dinars", 3, 0, "LD", "د.ل.‏")
            createCurrency("MAD", "Moroccan Dirham", 0, "Moroccan dirhams", 2, 0, "MAD", "د.م.‏")
            createCurrency("MDL", "Moldovan Leu", 0, "Moldovan lei", 2, 0, "MDL", "MDL")
            createCurrency("MGA", "Malagasy Ariary", 0, "Malagasy Ariaries", 0, 0, "MGA", "MGA")
            createCurrency("MKD", "Macedonian Denar", 0, "Macedonian denari", 2, 0, "MKD", "MKD")
            createCurrency("MMK", "Myanma Kyat", 0, "Myanma kyats", 0, 0, "MMK", "K")
            createCurrency("MOP", "Macanese Pataca", 0, "Macanese patacas", 2, 0, "MOP$", "MOP$")
            createCurrency("MUR", "Mauritian Rupee", 0, "Mauritian rupees", 0, 0, "MURs", "MURs")
            createCurrency("MWK", "Malawian Kwacha", 0, "Malawian Kwacha", 2, 0, "MK", "MK")
            createCurrency("MXN", "Mexican Peso", 0, "Mexican pesos", 2, 0, "MX$", "$")
            createCurrency("MYR", "Malaysian Ringgit", 0, "Malaysian ringgits", 2, 0, "RM", "RM")
            createCurrency("MZN", "Mozambican Metical", 0, "Mozambican meticals", 2, 0, "MTn", "MTn")
            createCurrency("NAD", "Namibian Dollar", 0, "Namibian dollars", 2, 0, "N$", "N$")
            createCurrency("NGN", "Nigerian Naira", 0, "Nigerian nairas", 2, 0, "₦", "₦")
            createCurrency("NIO", "Nicaraguan Córdoba", 0, "Nicaraguan córdobas", 2, 0, "C$", "C$")
            createCurrency("NOK", "Norwegian Krone", 0, "Norwegian kroner", 2, 0, "Nkr", "kr")
            createCurrency("NPR", "Nepalese Rupee", 0, "Nepalese rupees", 2, 0, "NPRs", "नेरू")
            createCurrency("NZD", "New Zealand Dollar", 0, "New Zealand dollars", 2, 0, "NZ$", "$")
            createCurrency("OMR", "Omani Rial", 0, "Omani rials", 3, 0, "OMR", "ر.ع.‏")
            createCurrency("PAB", "Panamanian Balboa", 0, "Panamanian balboas", 2, 0, "B/.", "B/.")
            createCurrency("PEN", "Peruvian Nuevo Sol", 0, "Peruvian nuevos soles", 2, 0, "S/.", "S/.")
            createCurrency("PHP", "Philippine Peso", 0, "Philippine pesos", 2, 0, "₱", "₱")
            createCurrency("PKR", "Pakistani Rupee", 0, "Pakistani rupees", 0, 0, "PKRs", "₨")
            createCurrency("PLN", "Polish Zloty", 0, "Polish zlotys", 2, 0, "zł", "zł")
            createCurrency("PYG", "Paraguayan Guarani", 0, "Paraguayan guaranis", 0, 0, "₲", "₲")
            createCurrency("QAR", "Qatari Rial", 0, "Qatari rials", 2, 0, "QR", "ر.ق.‏")
            createCurrency("RON", "Romanian Leu", 0, "Romanian lei", 2, 0, "RON", "RON")
            createCurrency("RSD", "Serbian Dinar", 0, "Serbian dinars", 0, 0, "din.", "дин.")
            createCurrency("RUB", "Russian Ruble", 0, "Russian rubles", 2, 0, "RUB", "руб.")
            createCurrency("RWF", "Rwandan Franc", 0, "Rwandan francs", 0, 0, "RWF", "FR")
            createCurrency("SAR", "Saudi Riyal", 0, "Saudi rials", 2, 0, "SR", "ر.س.‏")
            createCurrency("SBD", "Solomon Islander Dollar", 0, "Solomon Islander Dollars", 2, 0, "$", "$")
            createCurrency("SDG", "Sudanese Pound", 0, "Sudanese pounds", 2, 0, "SDG", "SDG")
            createCurrency("SEK", "Swedish Krona", 0, "Swedish kronor", 2, 0, "Skr", "kr")
            createCurrency("SGD", "Singapore Dollar", 0, "Singapore dollars", 2, 0, "S$", "$")
            createCurrency("SLL", "Sierra Leonean Leone", 0, "Sierra Leonean Leone", 2, 0, "Le", "Le")
            createCurrency("SOS", "Somali Shilling", 0, "Somali shillings", 0, 0, "Ssh", "Ssh")
            createCurrency("SSP", "South Sudanese pound", 0, "South Sudanese pound", 2, 0, "£", "£")
            createCurrency("STD", "Sao Tomean Dobra", 0, "Sao Tomean Dobra", 0, 0, "Db", "Db")
            createCurrency("STN", "Sao Tomean Dobra", 0, "Sao Tomean Dobra", 0, 0, "Db", "Db")
            createCurrency("SYP", "Syrian Pound", 0, "Syrian pounds", 0, 0, "SY£", "ل.س.‏")
            createCurrency("SZL", "Swazi Lilangeni", 0, "Swazi Lilangeni", 0, 0, "L", "L‏")
            createCurrency("THB", "Thai Baht", 0, "Thai baht", 2, 0, "฿", "฿")
            createCurrency("TJS", "Tajikistani Somoni", 0, "Tajikistani Somoni", 2, 0, "ЅМ", "ЅМ")
            createCurrency("TND", "Tunisian Dinar", 0, "Tunisian dinars", 3, 0, "DT", "د.ت.‏")
            createCurrency("TOP", "Tongan Paʻanga", 0, "Tongan paʻanga", 2, 0, "T$", "T$")
            createCurrency("TRY", "Turkish Lira", 0, "Turkish Lira", 2, 0, "TL", "TL")
            createCurrency("TTD", "Trinidad and Tobago Dollar", 0, "Trinidad and Tobago dollars", 2, 0, "TT$", "$")
            createCurrency("TWD", "New Taiwan Dollar", 0, "New Taiwan dollars", 2, 0, "NT$", "NT$")
            createCurrency("TZS", "Tanzanian Shilling", 0, "Tanzanian shillings", 0, 0, "TSh", "TSh")
            createCurrency("UAH", "Ukrainian Hryvnia", 0, "Ukrainian hryvnias", 2, 0, "₴", "₴")
            createCurrency("UGX", "Ugandan Shilling", 0, "Ugandan shillings", 0, 0, "USh", "USh")
            createCurrency("UYU", "Uruguayan Peso", 0, "Uruguayan pesos", 2, 0, "$U", "$")
            createCurrency("UZS", "Uzbekistan Som", 0, "Uzbekistan som", 0, 0, "UZS", "UZS")
            createCurrency("VEF", "Venezuelan Bolívar", 0, "Venezuelan bolívars", 2, 0, "Bs.F.", "Bs.F.")
            createCurrency("VND", "Vietnamese Dong", 0, "Vietnamese dong", 0, 0, "₫", "₫")
            createCurrency("VUV", "Ni-Vanuatu Vatu", 0, "Ni-Vanuatu Vatu", 0, 0, "Vt", "Vt")
            createCurrency("XAF", "CFA Franc BEAC", 0, "CFA francs BEAC", 0, 0, "FCFA", "FCFA")
            createCurrency("XCD", "East Caribbean Dollar", 0, "East Caribbean Dollars", 0, 0, "$", "$")
            createCurrency("XOF", "CFA Franc BCEAO", 0, "CFA francs BCEAO", 0, 0, "CFA", "CFA")
            createCurrency("XPF", "CFP franc", 0, "CFP franc", 0, 0, "Fr", "Fr")
            createCurrency("YER", "Yemeni Rial", 0, "Yemeni rials", 0, 0, "YR", "ر.ي.‏")
            createCurrency("ZAR", "South African Rand", 0, "South African rand", 2, 0, "R", "R")
            createCurrency("ZMK", "Zambian Kwacha", 0, "Zambian kwachas", 0, 0, "ZK", "ZK")
            createCurrency("USD", "US Dollar", 840, "US Dollar", 2, 2, "$", "$")
            
            try context.save()
            print("✅ Currencies seeded successfully.")
            
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

import SwiftUI

class LocalizationManager: ObservableObject {

    @AppStorage("currentLanguage") var currentLanguage: String = "en" {
        didSet {
            objectWillChange.send()
        }
    }

    func localize(key: String) -> String {
        // Попытка найти перевод в бандле для выбранного языка
        if let currentLangPath = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
           let currentLangBundle = Bundle(path: currentLangPath) {
            
            let translatedString = currentLangBundle.localizedString(forKey: key, value: nil, table: nil)
            // localizedString(forKey:) возвращает сам ключ, если перевод не найден.
            // Проверяем, отличается ли результат от ключа.
            if translatedString != key {
                return translatedString
            }
        }

        // Если перевод на выбранном языке не найден, принудительно ищем в английском (базовом)
        if currentLanguage != "en" {
            if let enPath = Bundle.main.path(forResource: "en", ofType: "lproj"),
               let enBundle = Bundle(path: enPath) {
                let enString = enBundle.localizedString(forKey: key, value: nil, table: nil)
                if enString != key {
                    return enString
                }
            }
        }
        
        // Если ничего не найдено, возвращаем сам ключ, чтобы было видно, где не хватает перевода.
        return key
    }
}

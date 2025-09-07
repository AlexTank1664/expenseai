//
//  LocalizationManager.swift
//  expenseai
//
//  Created by Mac on 07.09.2025.
//

import Foundation
class LocalizationManager {
    static func changeLanguage(to languageCode: String) {
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    static func localize(key: String) -> String {
        return NSLocalizedString(key, comment: "")
    }
}

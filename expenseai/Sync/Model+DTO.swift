import Foundation

// MARK: - DTO (Data Transfer Objects)

// DTO - это `Codable` представления наших Core Data моделей.
// Мы используем их для сериализации в JSON для отправки на сервер
// и для десериализации из JSON при получении данных с сервера.

extension Participant: DTOConvertible {
    struct DTO: Codable, Identifiable {
        let id: UUID
        let name: String
        let email: String?
        let phone: String?
        let isSoftDeleted: Bool
        let updatedAt: Date
        
        // This field will only be present in the response when a merge-by-email occurs.
        let clientId: UUID?
    }
    
    func toDTO() -> DTO? {
        guard let id = self.id, let updatedAt = self.updatedAt else {
            print("⚠️ Skipping Participant with missing id or updatedAt.")
            return nil
        }
        return DTO(
            id: id,
            name: self.name ?? "",
            email: self.email,
            phone: self.phone,
            isSoftDeleted: self.isSoftDeleted,
            updatedAt: updatedAt,
            clientId: nil // We never send this field to the server, so it's always nil here.
        )
    }
}

extension Group: DTOConvertible {
    struct DTO: Codable, Identifiable {
        let id: UUID
        let name: String
        let defaultCurrencyCode: String
        let memberIDs: [UUID]
        let isSoftDeleted: Bool
        let updatedAt: Date
    }
    
    func toDTO() -> DTO? {
        guard let id = self.id,
              let updatedAt = self.updatedAt,
              let currencyCode = self.defaultCurrency?.c_code else {
            print("⚠️ Skipping Group with missing id, updatedAt, or defaultCurrency. Group: \(self.name ?? "N/A")")
            return nil
        }
        
        return DTO(
            id: id,
            name: self.name ?? "",
            defaultCurrencyCode: currencyCode,
            memberIDs: self.membersArray.compactMap { $0.id },
            isSoftDeleted: self.isSoftDeleted,
            updatedAt: updatedAt
        )
    }
}

extension Expense: DTOConvertible {
    struct DTO: Codable, Identifiable {
        let id: UUID
        let desc: String
        let amount: Double
        let is_settlement: Bool
        let groupID: UUID
        let currencyCode: String
        let paidByID: UUID
        let shares: [ExpenseShare.DTO]
        let isSoftDeleted: Bool
        let updatedAt: Date
    }
    
    func toDTO() -> DTO? {
        // Use guard let for safe unwrapping. If any required relationship is missing,
        // we print a warning and return nil, preventing the app from crashing.
        guard let id = self.id,
              let updatedAt = self.updatedAt,
              let groupID = self.group?.id,
              let currencyCode = self.currency?.c_code,
              let paidByID = self.paidBy?.id else {
            print("⚠️ Skipping inconsistent expense record. Expense desc: \(self.desc ?? "N/A")")
            return nil
        }

        // Also ensure all shares can be converted
        let shareDTOs = self.sharesArray.compactMap { $0.toDTO() }
        if shareDTOs.count != self.sharesArray.count {
            print("⚠️ Skipping expense due to inconsistent shares. Expense desc: \(self.desc ?? "N/A")")
            return nil
        }
        
        return DTO(
            id: id,
            desc: self.desc ?? "",
            amount: self.amount,
            is_settlement: self.is_settlement,
            groupID: groupID,
            currencyCode: currencyCode,
            paidByID: paidByID,
            shares: shareDTOs,
            isSoftDeleted: self.isSoftDeleted,
            updatedAt: updatedAt
        )
    }
}

extension ExpenseShare: DTOConvertible {
    struct DTO: Codable, Identifiable {
        let id: UUID
        let participantID: UUID
        let amount: Double
    }
    
    func toDTO() -> DTO? {
        guard let id = self.id, let participantID = self.participant?.id else {
            print("⚠️ Skipping inconsistent expense share record.")
            return nil
        }
        
        return DTO(
            id: id,
            participantID: participantID,
            amount: self.amount
        )
    }
}

// Currency is special: it doesn't need a complex DTO for sending,
// but it needs one for receiving from the server.
extension Currency: DTOConvertible {
    struct DTO: Codable, Identifiable {
        var id: String { c_code } // Use c_code as the unique ID for Codable purposes
        
        let c_code: String
        let currency_name: String
        let i_code: Int16
        let currency_name_plural: String
        let decimal_digits: Int16
        let rounding: Double
        let symbol: String
        let symbol_native: String
    }
    
    func toDTO() -> DTO? {
        guard let c_code = self.c_code,
              let currency_name = self.currency_name,
              let currency_name_plural = self.currency_name_plural,
              let symbol = self.symbol,
              let symbol_native = self.symbol_native else {
            return nil
        }
        
        return DTO(
            c_code: c_code,
            currency_name: currency_name,
            i_code: self.i_code,
            currency_name_plural: currency_name_plural,
            decimal_digits: self.decimal_digits,
            rounding: self.rounding,
            symbol: symbol,
            symbol_native: symbol_native
        )
    }
}

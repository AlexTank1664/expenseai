import Foundation

// MARK: - DTO (Data Transfer Objects)

// DTO - это `Codable` представления наших Core Data моделей.
// Мы используем их для сериализации в JSON для отправки на сервер
// и для десериализации из JSON при получении данных с сервера.

protocol DTOConvertible {
    associatedtype DTO: Codable
    func toDTO() -> DTO
}

protocol DTOInstantiable {
    associatedtype DTO: Codable
    static func fromDTO(_ dto: DTO) -> Self
}


extension Participant {
    struct DTO: Codable {
        let id: UUID
        let name: String
        let email: String?
        let phone: String?
        let isSoftDeleted: Bool
        let updatedAt: Date
    }
    
    func toDTO() -> DTO {
        DTO(
            id: self.id!,
            name: self.name ?? "",
            email: self.email,
            phone: self.phone,
            isSoftDeleted: self.isSoftDeleted,
            updatedAt: self.updatedAt!
        )
    }
}

extension Group {
    struct DTO: Codable {
        let id: UUID
        let name: String
        let defaultCurrencyCode: String // Отправляем код, а не весь объект
        let memberIDs: [UUID] // Отправляем массив ID участников
        let isSoftDeleted: Bool
        let updatedAt: Date
    }
    
    func toDTO() -> DTO {
        DTO(
            id: self.id!,
            name: self.name ?? "",
            defaultCurrencyCode: self.defaultCurrency?.c_code ?? "",
            memberIDs: self.membersArray.compactMap { $0.id },
            isSoftDeleted: self.isSoftDeleted,
            updatedAt: self.updatedAt!
        )
    }
}

extension Expense {
    struct DTO: Codable {
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
    
    func toDTO() -> DTO {
        DTO(
            id: self.id!,
            desc: self.desc ?? "",
            amount: self.amount,
            is_settlement: self.is_settlement,
            groupID: self.group!.id!,
            currencyCode: self.currency!.c_code!,
            paidByID: self.paidBy!.id!,
            shares: self.sharesArray.map { $0.toDTO() },
            isSoftDeleted: self.isSoftDeleted,
            updatedAt: self.updatedAt!
        )
    }
}

extension ExpenseShare {
    struct DTO: Codable {
        // Заметьте, у долей нет isSoftDeleted или updatedAt,
        // они полностью зависят от родительской затраты.
        let id: UUID
        let participantID: UUID
        let amount: Double
    }
    
    func toDTO() -> DTO {
        DTO(
            id: self.id!,
            participantID: self.participant!.id!,
            amount: self.amount
        )
    }
}
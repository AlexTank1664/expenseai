import Foundation

// MARK: - Протоколы для конвертации

protocol DTOConvertible {
    associatedtype DTO: Codable
    func toDTO() -> DTO
}

protocol DTOInstantiable {
    associatedtype DTO: Codable
    // TODO: В будущем понадобится для PULL логики
    // static func fromDTO(_ dto: DTO, in context: NSManagedObjectContext) -> Self
}


// MARK: - Структуры для тела запроса/ответа

/// Полезная нагрузка, которую клиент отправляет на сервер.
struct SyncRequestPayload: Codable {
    let lastSyncTimestamp: Date?
    let changes: ChangesPayload
}

/// Полезная нагрузка, которую сервер присылает клиенту.
struct SyncResponsePayload: Codable {
    let serverTimestamp: Date
    let changes: ChangesPayload
}

/// Контейнер для всех измененных объектов (DTO).
struct ChangesPayload: Codable {
    var participants: [Participant.DTO]?
    var groups: [Group.DTO]?
    var expenses: [Expense.DTO]?
    
    static var empty: ChangesPayload {
        ChangesPayload()
    }
}
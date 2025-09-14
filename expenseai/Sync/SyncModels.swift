import Foundation

protocol DTOConvertible {
    associatedtype DTO: Codable, Identifiable
    func toDTO() -> DTO?
}

/// `ChangesPayload` - это структура, которая содержит массивы всех
/// измененных объектов (DTO) для отправки на сервер или применения локально.
struct ChangesPayload: Codable {
    var participants: [Participant.DTO]?
    var groups: [Group.DTO]?
    var expenses: [Expense.DTO]?
    
    static var empty: ChangesPayload {
        ChangesPayload()
    }
}

// MARK: - Sync Payloads

/// `SyncRequestPayload` - это то, что клиент отправляет на сервер.
struct SyncRequestPayload: Codable {
    /// Timestamp последней успешной синхронизации.
    /// Сервер использует это, чтобы понять, какие изменения нам нужны.
    /// Может быть nil, если это первая синхронизация.
    let lastSyncTimestamp: Date?
    
    /// Локальные изменения, которые нужно отправить на сервер.
    let changes: ChangesPayload
}

/// `SyncResponsePayload` - это то, что сервер присылает в ответ.
struct SyncResponsePayload: Codable {
    /// Текущее время на сервере после применения наших изменений.
    /// Мы сохраним это и будем использовать в следующем запросе.
    let serverTimestamp: Date
    
    /// Изменения с сервера, которые нам нужно применить локально.
    let changes: ChangesPayload
}
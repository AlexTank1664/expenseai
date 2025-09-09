import Foundation
import CoreData

/// `SyncEngine` - это центральный класс, отвечающий за всю логику синхронизации.
/// Он работает с Core Data и APIService, но ничего не знает о SwiftUI.
@MainActor
final class SyncEngine {
    
    private let context: NSManagedObjectContext
    private let apiService: APIService
    
    // Ключ для хранения даты последней синхронизации в UserDefaults
    private let lastSyncTimestampKey = "lastSyncTimestamp"
    
    private var lastSyncTimestamp: Date? {
        get {
            UserDefaults.standard.object(forKey: lastSyncTimestampKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastSyncTimestampKey)
        }
    }

    init(context: NSManagedObjectContext, apiService: APIService = .shared) {
        self.context = context
        self.apiService = apiService
    }
    
    /// Основной метод, запускающий полный цикл синхронизации.
    func sync() async throws {
        print("Sync started...")
        
        // Шаг 1: PUSH - Отправка локальных изменений на сервер
        let pushPayload = try await gatherLocalChanges()
        
        // TODO: Реализовать отправку на сервер, когда API будет готов
        // let pushResponse = try await apiService.performSync(payload: pushPayload)
        
        // После успешного PUSH, сбросить флаги needsSync
        // try await markPushedObjectsAsSynced(payload: pushPayload)

        // Шаг 2: PULL - Запрос изменений с сервера
        let pullRequestPayload = SyncRequestPayload(lastSyncTimestamp: lastSyncTimestamp, changes: .empty)
        let serverResponse = try await apiService.performSync(payload: pullRequestPayload)
        
        // Шаг 3: RECONCILIATION - Применение серверных изменений к локальной базе
        try await applyServerChanges(serverResponse.changes)
        
        // Шаг 4: Сохранение нового timestamp'а
        self.lastSyncTimestamp = serverResponse.serverTimestamp
        
        print("Sync finished successfully. New timestamp: \(String(describing: self.lastSyncTimestamp))")
    }
    
    // MARK: - PUSH Logic
    
    private func gatherLocalChanges() async throws -> SyncRequestPayload {
        // TODO: Найти все объекты с needsSync == true,
        // конвертировать их в DTO и вернуть в виде SyncRequestPayload.
        print("Gathering local changes...")
        return SyncRequestPayload(lastSyncTimestamp: lastSyncTimestamp, changes: .empty)
    }
    
    private func markPushedObjectsAsSynced(payload: SyncRequestPayload) async throws {
        // TODO: После успешной отправки, найти все отправленные объекты
        // по их UUID и установить needsSync = false.
        print("Marking pushed objects as synced...")
    }

    // MARK: - PULL Logic
    
    private func applyServerChanges(_ changes: ChangesPayload) async throws {
        // TODO: Реализовать логику сверки (reconciliation).
        // - Найти локальный объект по ID.
        // - Если не найден -> создать.
        // - Если найден -> сравнить updatedAt и обновить, если серверная версия новее.
        // - Если isSoftDeleted -> удалить локально.
        print("Applying server changes...")
        
        // Важно соблюдать порядок: сначала участники и группы, потом затраты.
        // try await applyChanges(for: changes.participants, entity: Participant.self)
        // try await applyChanges(for: changes.groups, entity: Group.self)
        // try await applyChanges(for: changes.expenses, entity: Expense.self)
        
        if context.hasChanges {
            try context.save()
        }
    }
}
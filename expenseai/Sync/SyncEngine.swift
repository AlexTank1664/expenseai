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
        
        // Шаг 1: PUSH - Сбор и отправка локальных изменений на сервер
        let pushPayload = try await gatherLocalChanges()
        
        // PUSH + PULL выполняются одним сетевым запросом.
        // Мы отправляем наши изменения, а сервер в ответ присылает свои.
        let serverResponse = try await apiService.performSync(payload: pushPayload)
        
        // Шаг 2: RECONCILIATION - Применение серверных изменений к локальной базе
        try await applyServerChanges(serverResponse.changes)
        
        // Шаг 3: PUSH Cleanup - Сбрасываем флаги `needsSync` для успешно отправленных объектов
        try await markPushedObjectsAsSynced(payload: pushPayload)

        // Шаг 4: Сохранение нового timestamp'а
        self.lastSyncTimestamp = serverResponse.serverTimestamp
        
        print("Sync finished successfully. New timestamp: \(String(describing: self.lastSyncTimestamp))")
    }
    
    // MARK: - PUSH Logic
    
    private func gatherLocalChanges() async throws -> SyncRequestPayload {
        print("Gathering local changes...")
        
        // Используем `perform` для безопасной работы с Core Data в фоновом потоке.
        return try await context.perform { [self] in
            // Собираем все измененные объекты
            let participants = try self.fetchPendingObjects(entity: Participant.self)
            let groups = try self.fetchPendingObjects(entity: Group.self)
            let expenses = try self.fetchPendingObjects(entity: Expense.self)
            
            // Если изменений нет, можно даже не отправлять запрос.
            // (Эту логику можно будет добавить позже)
            
            let changes = ChangesPayload(
                participants: participants,
                groups: groups,
                expenses: expenses
            )
            
            return SyncRequestPayload(lastSyncTimestamp: self.lastSyncTimestamp, changes: changes)
        }
    }
    
    /// Обобщенный метод для поиска всех объектов с флагом `needsSync = true`
    /// и преобразования их в соответствующий DTO.
    private func fetchPendingObjects<T>(entity: T.Type) throws -> [T.DTO] where T: NSManagedObject, T: DTOConvertible {
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: entity))
        fetchRequest.predicate = NSPredicate(format: "needsSync == YES")
        
        let results = try context.fetch(fetchRequest)
        
        // Преобразуем найденные Core Data объекты в их DTO версии
        let dtos = results.map { $0.toDTO() }
        
        if !dtos.isEmpty {
            print("Found \(dtos.count) pending \(String(describing: entity))s to push.")
        }
        
        return dtos
    }
    
    private func markPushedObjectsAsSynced(payload: SyncRequestPayload) async throws {
        print("Marking pushed objects as synced...")
        
        try await context.perform { [self] in
            let changes = payload.changes
            
            // Собираем ID всех объектов, которые мы только что отправили
            let participantIDs = changes.participants?.map { $0.id } ?? []
            let groupIDs = changes.groups?.map { $0.id } ?? []
            let expenseIDs = changes.expenses?.map { $0.id } ?? []

            // Сбрасываем флаги `needsSync` для каждой сущности
            try self.batchUpdateNeedsSyncFlag(for: participantIDs, entityName: Participant.entity().name!)
            try self.batchUpdateNeedsSyncFlag(for: groupIDs, entityName: Group.entity().name!)
            try self.batchUpdateNeedsSyncFlag(for: expenseIDs, entityName: Expense.entity().name!)
            
            // Если были изменения, сохраняем контекст.
            // Batch update не делает это автоматически.
            if context.hasChanges {
                try context.save()
            }
        }
    }
    
    /// Эффективно обновляет флаг `needsSync` для массива объектов, не загружая их в память.
    private func batchUpdateNeedsSyncFlag(for ids: [UUID], entityName: String) throws {
        guard !ids.isEmpty else { return }
        
        let batchUpdateRequest = NSBatchUpdateRequest(entityName: entityName)
        batchUpdateRequest.predicate = NSPredicate(format: "id IN %@", ids)
        batchUpdateRequest.propertiesToUpdate = ["needsSync": false]
        batchUpdateRequest.resultType = .updatedObjectsCountResultType
        
        try context.execute(batchUpdateRequest)
        print("Reset needsSync flag for \(ids.count) objects in \(entityName).")
    }

    // MARK: - PULL Logic
    
    private func applyServerChanges(_ changes: ChangesPayload) async throws {
        try await context.perform { [self] in
            // Важно соблюдать порядок: сначала независимые сущности, потом зависимые.
            
            // --- Применяем изменения для Участников (Participants) ---
            if let participantDTOs = changes.participants {
                try self.applyParticipantChanges(participantDTOs)
            }
            
            // --- Применяем изменения для Групп (Groups) ---
            if let groupDTOs = changes.groups {
                try self.applyGroupChanges(groupDTOs)
            }
            
            // --- Применяем изменения для Затрат (Expenses) ---
            if let expenseDTOs = changes.expenses {
                try self.applyExpenseChanges(expenseDTOs)
            }

            if context.hasChanges {
                print("Saving applied changes to Core Data.")
                try context.save()
            } else {
                print("No server changes needed to be saved.")
            }
        }
    }

    private func applyParticipantChanges(_ dtos: [Participant.DTO]) throws {
        // Эффективно находим всех существующих участников одним запросом
        let dtoIDs = dtos.map { $0.id }
        let fetchRequest = Participant.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", dtoIDs)
        let existingParticipants = try context.fetch(fetchRequest)
        let existingParticipantsDict = Dictionary(uniqueKeysWithValues: existingParticipants.map { ($0.id!, $0) })

        for dto in dtos {
            let participant = existingParticipantsDict[dto.id] ?? Participant(context: context)

            // Сценарий 3: Удаление
            if dto.isSoftDeleted {
                context.delete(participant)
                continue
            }

            // Сценарий 2: Обновление (если серверная версия новее)
            if let localDate = participant.updatedAt, localDate >= dto.updatedAt {
                continue // Локальная версия новее или такая же, пропускаем
            }

            // Сценарий 1 и 2: Создание или Обновление данных
            participant.id = dto.id
            participant.name = dto.name
            participant.email = dto.email
            participant.phone = dto.phone
            participant.updatedAt = dto.updatedAt
            participant.isSoftDeleted = false
            participant.needsSync = false // Данные только что с сервера, синхронизировать не нужно
        }
    }

    private func applyGroupChanges(_ dtos: [Group.DTO]) throws {
        let dtoIDs = dtos.map { $0.id }
        let fetchRequest = Group.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", dtoIDs)
        let existingGroups = try context.fetch(fetchRequest)
        let existingGroupsDict = Dictionary(uniqueKeysWithValues: existingGroups.map { ($0.id!, $0) })

        // Также эффективно находим все нужные валюты и участников для установки связей
        let currencyCodes = Set(dtos.map { $0.defaultCurrencyCode })
        let memberIDs = Set(dtos.flatMap { $0.memberIDs })
        
        let currencies = try fetchCurrencies(with: currencyCodes)
        let members = try fetchParticipants(with: memberIDs)

        for dto in dtos {
            let group = existingGroupsDict[dto.id] ?? Group(context: context)

            if dto.isSoftDeleted {
                context.delete(group)
                continue
            }
            if let localDate = group.updatedAt, localDate >= dto.updatedAt {
                continue
            }

            group.id = dto.id
            group.name = dto.name
            group.updatedAt = dto.updatedAt
            group.defaultCurrency = currencies[dto.defaultCurrencyCode]
            
            // Обновляем состав участников
            let groupMembers = dto.memberIDs.compactMap { members[$0] }
            group.members = NSSet(array: groupMembers)
            
            group.isSoftDeleted = false
            group.needsSync = false
        }
    }

    private func applyExpenseChanges(_ dtos: [Expense.DTO]) throws {
        // 1. Эффективно находим все существующие затраты одним запросом
        let dtoIDs = dtos.map { $0.id }
        let fetchRequest = Expense.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", dtoIDs)
        let existingExpenses = try context.fetch(fetchRequest)
        let existingExpensesDict = Dictionary(uniqueKeysWithValues: existingExpenses.map { ($0.id!, $0) })

        // 2. Заранее подгружаем ВСЕ связанные объекты, которые могут понадобиться
        let groupIDs = Set(dtos.map { $0.groupID })
        let currencyCodes = Set(dtos.map { $0.currencyCode })
        let payerIDs = Set(dtos.map { $0.paidByID })
        let shareParticipantIDs = Set(dtos.flatMap { $0.shares.map { $0.participantID } })
        let allParticipantIDs = payerIDs.union(shareParticipantIDs)

        let groups = try fetchGroups(with: groupIDs)
        let currencies = try fetchCurrencies(with: currencyCodes)
        let participants = try fetchParticipants(with: allParticipantIDs)

        // 3. Проходим по DTO и применяем изменения
        for dto in dtos {
            let expense = existingExpensesDict[dto.id] ?? Expense(context: context)

            // Сценарий 3: Удаление
            if dto.isSoftDeleted {
                context.delete(expense) // Каскадное удаление само удалит доли (shares)
                continue
            }

            // Сценарий 2: Обновление (проверяем, что серверная версия новее)
            if let localDate = expense.updatedAt, localDate >= dto.updatedAt {
                continue // Локальная версия новее или такая же, пропускаем
            }

            // Сценарий 1 и 2: Создание или Обновление данных
            expense.id = dto.id
            expense.desc = dto.desc
            expense.amount = dto.amount
            expense.is_settlement = dto.is_settlement
            expense.updatedAt = dto.updatedAt
            
            // Устанавливаем связи
            expense.group = groups[dto.groupID]
            expense.currency = currencies[dto.currencyCode]
            expense.paidBy = participants[dto.paidByID]
            
            // Обрабатываем доли: удаляем старые, создаем новые
            if let oldShares = expense.shares {
                expense.removeFromShares(oldShares)
            }
            
            var newShares = Set<ExpenseShare>()
            for shareDTO in dto.shares {
                let newShare = ExpenseShare(context: context)
                newShare.id = shareDTO.id
                newShare.amount = shareDTO.amount
                newShare.participant = participants[shareDTO.participantID]
                newShare.expense = expense // Устанавливаем обратную связь
                newShares.insert(newShare)
            }
            expense.addToShares(NSSet(set: newShares))
            
            expense.isSoftDeleted = false
            expense.needsSync = false
        }
    }
    
    // MARK: - Helper methods for fetching related objects
    
    private func fetchGroups(with ids: Set<UUID>) throws -> [UUID: Group] {
        let request = Group.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", ids)
        let results = try context.fetch(request)
        return Dictionary(uniqueKeysWithValues: results.map { ($0.id!, $0) })
    }
    
    private func fetchCurrencies(with codes: Set<String>) throws -> [String: Currency] {
        let request = Currency.fetchRequest()
        request.predicate = NSPredicate(format: "c_code IN %@", codes)
        let results = try context.fetch(request)
        return Dictionary(uniqueKeysWithValues: results.map { ($0.c_code!, $0) })
    }
    
    private func fetchParticipants(with ids: Set<UUID>) throws -> [UUID: Participant] {
        let request = Participant.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", ids)
        let results = try context.fetch(request)
        return Dictionary(uniqueKeysWithValues: results.map { ($0.id!, $0) })
    }
}
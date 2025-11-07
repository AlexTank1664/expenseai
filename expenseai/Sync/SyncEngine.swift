import Foundation
import CoreData

// Протокол для сущностей, которые можно синхронизировать.
// Требует статического свойства `endpoint` для указания пути в API.
protocol Syncable: NSManagedObject, DTOConvertible where DTO: Codable {
    static var endpoint: String { get }
}

// Расширяем наши модели, чтобы они соответствовали `Syncable`.
extension Participant: Syncable { static var endpoint: String = APIConstants.Endpoints.participants }
extension Group: Syncable { static var endpoint: String = APIConstants.Endpoints.groups }
extension Expense: Syncable { static var endpoint: String = APIConstants.Endpoints.expenses }
// Currency is not syncable in the same way (push/pull), it's pull-only.
// We handle it as a special case in the sync coordinator.

@MainActor
final class SyncEngine: ObservableObject {
    
    // MARK: - Published Properties for UI
    @Published var isSyncing: Bool = false
    @Published var syncProgressMessage: String = ""

    // MARK: - Private Properties
    private let context: NSManagedObjectContext
    private let apiService: APIService
    private let authService: AuthService
    
    // Ключ для хранения даты последней синхронизации в UserDefaults
    private let lastSyncTimestampKey = "lastSyncTimestamp"
    private var lastSyncTimestamp: Date? {
        get { UserDefaults.standard.object(forKey: lastSyncTimestampKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastSyncTimestampKey) }
    }

    // MARK: - Initializer
    init(context: NSManagedObjectContext, apiService: APIService = .shared, authService: AuthService) {
        self.context = context
        self.apiService = apiService
        self.authService = authService
    }
    
    // MARK: - Main Sync Coordinator
    
    func sync() async throws {
        guard !isSyncing else {
            print("Sync is already in progress.")
            return
        }
        guard let token = authService.authToken else {
            print("Sync aborted: User is not authenticated.")
            throw SyncError.notAuthenticated
        }
        
        isSyncing = true
        defer {
            isSyncing = false
            syncProgressMessage = ""
        }
        
        print("🚀 --- Starting Full Sync --- 🚀")
        
        // --- Шаг 1: Загрузка справочников (только PULL) ---
        syncProgressMessage = "Updating currencies..."
        try await pullAndApply(Currency.self, authToken: token)

        // --- Шаг 2: Синхронизация основных данных (PUSH, затем PULL) ---
        // Порядок важен для соблюдения зависимостей:
        // Участники -> Группы -> Затраты
        
        syncProgressMessage = "Updating participants..."
        try await syncEntity(Participant.self, authToken: token)
        
        syncProgressMessage = "Updating groups..."
        try await syncEntity(Group.self, authToken: token)
        
        syncProgressMessage = "Updating expenses..."
        try await syncEntity(Expense.self, authToken: token)

        // --- Шаг 3: Сохранение времени успешной синхронизации ---
        // Мы используем `Date()` здесь, чтобы зафиксировать время окончания,
        // а не время, которое пришло с сервера. Это консервативный подход.
        self.lastSyncTimestamp = Date()
        
        print("✅ --- Full Sync Finished Successfully --- ✅")
    }

    // MARK: - Generic Sync Logic
    
    /// Координирует PUSH и PULL для одной конкретной сущности.
    private func syncEntity<T: Syncable>(_ entityType: T.Type, authToken: String) async throws where T.DTO.ID == UUID {
        // PUSH: Отправляем локальные изменения на сервер
        let localChanges = try await fetchPendingObjects(entity: entityType)
        if !localChanges.isEmpty {
            print("☁️ Pushing \(localChanges.count) \(entityType.entity().name ?? "objects")...")
            let serverAcknowledgedDTOs = try await apiService.post(items: localChanges, endpoint: T.endpoint, authToken: authToken)
            
            // --- MERGE LOGIC ---
            // If we are syncing participants, check for any merged records.
            if let participantDTOs = serverAcknowledgedDTOs as? [Participant.DTO] {
                try await handleParticipantMerges(from: participantDTOs)
            }
            // --- END OF MERGE LOGIC ---
            
            // Сбрасываем флаг `needsSync` только для тех объектов,
            // которые сервер успешно принял и вернул.
            let idsToMarkAsSynced = serverAcknowledgedDTOs.map { $0.id }
            try await batchUpdateNeedsSyncFlag(for: idsToMarkAsSynced, entityName: T.entity().name!)
        } else {
            print("👍 No local changes to push for \(entityType.entity().name ?? "entity").")
        }
        
        // PULL: Загружаем изменения с сервера и применяем их
        try await pullAndApply(entityType, authToken: authToken)
    }

    /// Загружает данные с сервера и применяет их к локальной базе.
    private func pullAndApply<T: NSManagedObject & DTOConvertible>(_ entityType: T.Type, authToken: String) async throws where T.DTO: Decodable {
        let endpoint = (entityType as? (any Syncable.Type))?.endpoint ?? APIConstants.Endpoints.currencies
        print("☁️ Pulling remote changes for \(entityType.entity().name ?? "objects")...")
        
        // Загружаем DTO с сервера, используя `lastSyncTimestamp`
        let remoteDTOs: [T.DTO] = try await apiService.fetch(endpoint: endpoint, authToken: authToken, lastSyncTimestamp: self.lastSyncTimestamp)
        
        if remoteDTOs.isEmpty {
            print("👍 No remote changes to pull for \(entityType.entity().name ?? "entity").")
            return
        }
        
        print("Applying \(remoteDTOs.count) remote changes for \(entityType.entity().name ?? "entity")...")
        
        // Применяем изменения в контексте Core Data
        try await applyChanges(for: remoteDTOs, entityType: entityType, in: context)
    }

    // MARK: - Core Data Helpers
    
    /// Handles the special case where the server merges a participant record via email.
    /// It finds the local record by `clientId` and updates its `id` to the server's `id`.
    private func handleParticipantMerges(from dtos: [Participant.DTO]) async throws {
        // Filter out only the DTOs that represent a merge.
        let mergeDTOs = dtos.filter { $0.clientId != nil }
        
        guard !mergeDTOs.isEmpty else { return } // Nothing to merge
        
        print("🔄 Handling \(mergeDTOs.count) participant merges...")
        
        try await context.perform {
            for dto in mergeDTOs {
                guard let clientId = dto.clientId else { continue }
                
                // Find the local participant that has the old (client) ID.
                let fetchRequest = Participant.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", clientId as CVarArg)
                fetchRequest.fetchLimit = 1
                
                // If we find the participant, update its ID to the new canonical ID from the server.
                if let participantToUpdate = try self.context.fetch(fetchRequest).first {
                    print("Merging participant: \(participantToUpdate.name ?? "") | Old ID: \(clientId) -> New ID: \(dto.id)")
                    participantToUpdate.id = dto.id
                    // We don't need to set needsSync, as this is just an ID correction.
                }
            }
            
            // Save the context to persist the ID changes.
            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }
    
    /// Собирает все локальные объекты с флагом `needsSync = true`.
    private func fetchPendingObjects<T: Syncable>(entity: T.Type) async throws -> [T.DTO] {
        try await context.perform {
            let fetchRequest = NSFetchRequest<T>(entityName: T.entity().name!)
            fetchRequest.predicate = NSPredicate(format: "needsSync == YES")
            
            let results = try self.context.fetch(fetchRequest)
            return results.compactMap { $0.toDTO() }
        }
    }
    
    /// Сбрасывает флаг `needsSync` для успешно отправленных объектов.
    private func batchUpdateNeedsSyncFlag(for ids: [UUID], entityName: String) async throws {
        guard !ids.isEmpty else { return }
        try await context.perform {
            let batchUpdateRequest = NSBatchUpdateRequest(entityName: entityName)
            batchUpdateRequest.predicate = NSPredicate(format: "id IN %@", ids)
            batchUpdateRequest.propertiesToUpdate = ["needsSync": false]
            try self.context.execute(batchUpdateRequest)
            print("Reset needsSync flag for \(ids.count) objects in \(entityName).")
        }
    }
    
    // MARK: - Reconciliation (Applying Server Changes)
    
    // Здесь должна быть ваша логика применения изменений (applyChanges),
    // адаптированная для работы с дженериками, если это возможно,
    // или вызывающая специфичные методы (applyParticipantChanges и т.д.).
    // Для простоты, я пока оставлю вызовы ваших существующих методов.
    
    private func applyChanges(for dtos: [any Codable], entityType: NSManagedObject.Type, in context: NSManagedObjectContext) async throws {
        try await context.perform {
            // Определяем тип DTO и вызываем соответствующий метод для применения изменений
            if let participantDTOs = dtos as? [Participant.DTO] {
                try self.applyParticipantChanges(participantDTOs)
            } else if let groupDTOs = dtos as? [Group.DTO] {
                try self.applyGroupChanges(groupDTOs)
            } else if let expenseDTOs = dtos as? [Expense.DTO] {
                try self.applyExpenseChanges(expenseDTOs)
            } else if let currencyDTOs = dtos as? [Currency.DTO] {
                try self.applyCurrencyChanges(currencyDTOs)
            }
            
            if context.hasChanges {
                try context.save()
            }
        }
    }

    // MARK: - Entity-Specific Reconciliation Logic
    // (Ваши существующие методы apply... почти не изменились)

    private func applyParticipantChanges(_ dtos: [Participant.DTO]) throws {
        let dtoIDs = dtos.map { $0.id }
        let fetchRequest = Participant.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", dtoIDs)
        let existingParticipants = try context.fetch(fetchRequest)
        let existingParticipantsDict = Dictionary(uniqueKeysWithValues: existingParticipants.map { ($0.id!, $0) })

        for dto in dtos {
            let participant = existingParticipantsDict[dto.id] ?? Participant(context: context)
            
            // Всегда вызываем update. Теперь он сам правильно установит isSoftDeleted.
            participant.update(from: dto, in: context)
        }
    }

    private func applyGroupChanges(_ dtos: [Group.DTO]) throws {
        let dtoIDs = dtos.map { $0.id }
        let fetchRequest = Group.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", dtoIDs)
        let existingGroups = try context.fetch(fetchRequest)
        let existingGroupsDict = Dictionary(uniqueKeysWithValues: existingGroups.map { ($0.id!, $0) })

        // --- OPTIMIZATION: Pre-fetch all related objects needed for the updates ---
        //let currencyCodes = Set(dtos.map { $0.defaultCurrencyCode })
        let allMemberIDs = Set(dtos.flatMap { $0.memberIDs })
        
        //let currenciesByCode = try fetchCurrencies(with: currencyCodes, in: context)
        let currenciesByCode = try fetchAllCurrencies(in: context)
        
        let membersByID = try fetchParticipants(with: Array(allMemberIDs), in: context)
        // --- END OF OPTIMIZATION ---

        for dto in dtos {
            let group = existingGroupsDict[dto.id] ?? Group(context: context)
            if dto.isSoftDeleted {
                context.delete(group)
                continue
            }
            // Pass the pre-fetched dictionaries to the update method
            try group.update(from: dto, currencies: currenciesByCode, members: membersByID)
        }
    }

    private func applyExpenseChanges(_ dtos: [Expense.DTO]) throws {
        let dtoIDs = dtos.map { $0.id }
        let fetchRequest = Expense.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", dtoIDs)
        let existingExpenses = try context.fetch(fetchRequest)
        let existingExpensesDict = Dictionary(uniqueKeysWithValues: existingExpenses.map { ($0.id!, $0) })

        for dto in dtos {
            let expense = existingExpensesDict[dto.id] ?? Expense(context: context)
            if dto.isSoftDeleted {
                context.delete(expense)
                continue
            }
            try expense.update(from: dto, in: context)
        }
    }

    private func applyCurrencyChanges(_ dtos: [Currency.DTO]) throws {
        // More efficient version:
        // 1. Fetch all existing currencies in one go.
        // 2. Create a dictionary for quick lookups.
        // 3. Iterate through DTOs and update or create managed objects.
        let existingCurrencies = try context.fetch(Currency.fetchRequest())
        let existingCurrenciesDict = Dictionary(uniqueKeysWithValues: existingCurrencies.compactMap { currency -> (String, Currency)? in
            guard let code = currency.c_code else { return nil }
            return (code, currency)
        })

        for dto in dtos {
            // Find an existing currency or create a new one.
            let currency = existingCurrenciesDict[dto.c_code] ?? Currency(context: context)
            currency.update(from: dto)
        }
    }
}

// MARK: - Helper Extensions for Reconciliation
// Добавляем методы `update(from:)` к моделям, чтобы инкапсулировать логику обновления.

protocol Reconcilable {
    associatedtype DTO
    // The `in context` parameter is no longer needed if we pass dependencies directly.
    func update(from dto: DTO) throws
}

extension Participant: Reconcilable {
    // This one is simple and has no external dependencies, so we can keep the old signature for now.
    func update(from dto: Participant.DTO, in context: NSManagedObjectContext) {
        self.id = dto.id
        self.name = dto.name
        self.email = dto.email
        self.phone = dto.phone
        self.updatedAt = dto.updatedAt
        self.isSoftDeleted = dto.isSoftDeleted
        self.needsSync = false
    }
    
    // We add a dummy conformance to the new protocol requirement.
    func update(from dto: DTO) throws {
        // This is a bit of a workaround to satisfy the protocol.
        // The better long-term solution would be to refactor all `update` methods.
        guard let context = self.managedObjectContext else { return }
        self.update(from: dto, in: context)
    }
}

extension Group { // Remove Reconcilable from here for now to avoid protocol conflicts
    // Create a new, more efficient update method that accepts dependencies.
    func update(from dto: Group.DTO, currencies: [String: Currency], members: [UUID: Participant]) throws {
        self.id = dto.id
        self.name = dto.name
        self.updatedAt = dto.updatedAt
        self.isSoftDeleted = false
        self.needsSync = false
        
        // Связи
        // Use the pre-fetched dictionaries instead of fetching from the context.
        self.defaultCurrency = currencies[dto.defaultCurrencyCode]
        
        let groupMembers = dto.memberIDs.compactMap { members[$0] }
        self.members = NSSet(array: groupMembers)
    }
}

extension Expense: Reconcilable {
    func update(from dto: Expense.DTO, in context: NSManagedObjectContext) throws {
        self.id = dto.id
        self.desc = dto.desc
        self.amount = dto.amount
        self.is_settlement = dto.is_settlement
        self.createdAt = dto.createdAt
        self.updatedAt = dto.updatedAt
        self.isSoftDeleted = false
        self.needsSync = false

        // Связи
        self.group = try fetchGroup(with: dto.groupID, in: context)
        self.currency = try fetchCurrency(with: dto.currencyCode, in: context)
        self.paidBy = try fetchParticipant(with: dto.paidByID, in: context)
        
        // Обработка долей (shares)
        self.shares?.forEach { context.delete($0 as! NSManagedObject) }
        var newShares = Set<ExpenseShare>()
        for shareDTO in dto.shares {
            let newShare = ExpenseShare(context: context)
            newShare.id = shareDTO.id
            newShare.amount = shareDTO.amount
            newShare.participant = try fetchParticipant(with: shareDTO.participantID, in: context)
            newShares.insert(newShare)
        }
        self.shares = NSSet(set: newShares)
    }
    
    func update(from dto: DTO) throws {
        guard let context = self.managedObjectContext else { return }
        try self.update(from: dto, in: context)
    }
}

extension Currency {
    // У Currency нет сложных связей, поэтому `update` простой
    func update(from dto: Currency.DTO) {
        self.c_code = dto.c_code
        self.currency_name = dto.currency_name
        self.i_code = dto.i_code
        self.currency_name_plural = dto.currency_name_plural
        self.decimal_digits = dto.decimal_digits
        self.rounding = dto.rounding
        self.symbol = dto.symbol
        self.symbol_native = dto.symbol_native
        // `is_active` управляется локально, не трогаем
    }
}


// MARK: - Global Fetch Helpers for Reconciliation

// Эти функции помогают избежать дублирования кода при поиске связанных объектов.

func fetchCurrency(with code: String, in context: NSManagedObjectContext) throws -> Currency? {
    let request = Currency.fetchRequest()
    request.predicate = NSPredicate(format: "c_code == %@", code)
    request.fetchLimit = 1
    return try context.fetch(request).first
}

// Helper function to fetch a dictionary of currencies by their codes
func fetchCurrencies(with codes: Set<String>, in context: NSManagedObjectContext) throws -> [String: Currency] {
    guard !codes.isEmpty else { return [:] }
    let request = Currency.fetchRequest()
    request.predicate = NSPredicate(format: "c_code IN %@", codes)
    let results = try context.fetch(request)
    return Dictionary(uniqueKeysWithValues: results.compactMap {
        guard let code = $0.c_code else { return nil }
        return (code, $0)
    })
}

func fetchAllCurrencies(in context: NSManagedObjectContext) throws -> [String: Currency] {
  let request = Currency.fetchRequest()
  let results = try context.fetch(request)

  return Dictionary(uniqueKeysWithValues: results.compactMap {
      guard let code = $0.c_code else { return nil }
      return (code, $0)
  })
}


func fetchParticipant(with id: UUID, in context: NSManagedObjectContext) throws -> Participant? {
    let request = Participant.fetchRequest()
    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
    request.fetchLimit = 1
    return try context.fetch(request).first
}

func fetchParticipants(with ids: [UUID], in context: NSManagedObjectContext) throws -> [UUID: Participant] {
    guard !ids.isEmpty else { return [:] }
    let request = Participant.fetchRequest()
    request.predicate = NSPredicate(format: "id IN %@", ids)
    let results = try context.fetch(request)
    return Dictionary(uniqueKeysWithValues: results.map { ($0.id!, $0) })
}

func fetchGroup(with id: UUID, in context: NSManagedObjectContext) throws -> Group? {
    let request = Group.fetchRequest()
    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
    request.fetchLimit = 1
    return try context.fetch(request).first
}

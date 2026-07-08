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

final class SyncEngine: ObservableObject {
    
    // MARK: - Published Properties for UI
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var syncProgressMessage: String = ""

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
    
    // MARK: - UI Update Helper
    
    /// Обновляет UI-свойства в главном потоке
    private func updateUI(isSyncing: Bool? = nil, message: String? = nil) {
        Task { @MainActor in
            if let isSyncing = isSyncing {
                self.isSyncing = isSyncing
            }
            if let message = message {
                self.syncProgressMessage = message
            }
        }
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
        
        updateUI(isSyncing: true)
        defer {
            updateUI(isSyncing: false, message: "")
        }
        
        print("🚀 --- Starting Full Sync --- 🚀")
        
        // --- Шаг 1: Загрузка справочников (только PULL) ---
        updateUI(message: "Updating currencies...")
        try await pullAndApply(Currency.self, authToken: token)

        // --- Шаг 2: Синхронизация основных данных (PUSH, затем PULL) ---
        // Порядок важен для соблюдения зависимостей:
        // Участники -> Группы -> Затраты
        
        updateUI(message: "Updating participants...")
        try await syncEntity(Participant.self, authToken: token)
        
        updateUI(message: "Updating groups...")
        try await syncEntity(Group.self, authToken: token)
        
        updateUI(message: "Updating expenses...")
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
        
        let localContext = self.context
        
        try await localContext.perform {
            for dto in mergeDTOs {
                guard let clientId = dto.clientId else { continue }
                
                let fetchRequest = Participant.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", clientId as CVarArg)
                fetchRequest.fetchLimit = 1
                
                // ✅ Используем localContext вместо self.context
                if let participantToUpdate = try localContext.fetch(fetchRequest).first {
                    print("Merging participant: \(participantToUpdate.name ?? "") | Old ID: \(clientId) -> New ID: \(dto.id)")
                    participantToUpdate.id = dto.id
                }
            }
            
            if localContext.hasChanges {
                try localContext.save()
            }
        }
    }
    
    /// Собирает все локальные объекты с флагом `needsSync = true`.
    private func fetchPendingObjects<T: Syncable>(entity: T.Type) async throws -> [T.DTO] {
        let localContext = self.context  // ✅ Извлекаем в локальную переменную
        return try await localContext.perform {
            let fetchRequest = NSFetchRequest<T>(entityName: T.entity().name!)
            fetchRequest.predicate = NSPredicate(format: "needsSync == YES")
            
            let results = try localContext.fetch(fetchRequest)  // ✅ Используем localContext
            return results.compactMap { $0.toDTO() }
        }
    }
    
    /// Сбрасывает флаг `needsSync` для успешно отправленных объектов.
    private func batchUpdateNeedsSyncFlag(for ids: [UUID], entityName: String) async throws {
        guard !ids.isEmpty else { return }
        let localContext = self.context  // ✅ Извлекаем в локальную переменную
        try await localContext.perform {
            let batchUpdateRequest = NSBatchUpdateRequest(entityName: entityName)
            batchUpdateRequest.predicate = NSPredicate(format: "id IN %@", ids)
            batchUpdateRequest.propertiesToUpdate = ["needsSync": false]
            try localContext.execute(batchUpdateRequest)  // ✅ Используем localContext
            print("Reset needsSync flag for \(ids.count) objects in \(entityName).")
        }
    }
    
    // MARK: - Reconciliation (Applying Server Changes)
    
    private func applyChanges(for dtos: [any Codable], entityType: NSManagedObject.Type, in context: NSManagedObjectContext) async throws {
        let localContext = context
        try await localContext.perform {
            if let participantDTOs = dtos as? [Participant.DTO] {
                try Self.applyParticipantChanges(participantDTOs, in: localContext)
            } else if let groupDTOs = dtos as? [Group.DTO] {
                try Self.applyGroupChanges(groupDTOs, in: localContext)
            } else if let expenseDTOs = dtos as? [Expense.DTO] {
                try Self.applyExpenseChanges(expenseDTOs, in: localContext)
            } else if let currencyDTOs = dtos as? [Currency.DTO] {
                try Self.applyCurrencyChanges(currencyDTOs, in: localContext)
            }
            
            if localContext.hasChanges {
                try localContext.save()
            }
        }
    }

    // MARK: - Entity-Specific Reconciliation Logic
    // (Ваши существующие методы apply... почти не изменились)

    private static func applyParticipantChanges(_ dtos: [Participant.DTO], in context: NSManagedObjectContext) throws {
        let dtoIDs = dtos.map { $0.id }
        let fetchRequest = Participant.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", dtoIDs)
        let existingParticipants = try context.fetch(fetchRequest)
        let existingParticipantsDict = Dictionary(uniqueKeysWithValues: existingParticipants.map { ($0.id!, $0) })

        for dto in dtos {
            let participant = existingParticipantsDict[dto.id] ?? Participant(context: context)
            participant.update(from: dto, in: context)
        }
    }

    private static func applyGroupChanges(_ dtos: [Group.DTO], in context: NSManagedObjectContext) throws {
        let dtoIDs = dtos.map { $0.id }
        let fetchRequest = Group.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", dtoIDs)
        let existingGroups = try context.fetch(fetchRequest)
        let existingGroupsDict = Dictionary(uniqueKeysWithValues: existingGroups.map { ($0.id!, $0) })

        let allMemberIDs = Set(dtos.flatMap { $0.memberIDs })
        let currenciesByCode = try fetchAllCurrencies(in: context)
        let membersByID = try fetchParticipants(with: Array(allMemberIDs), in: context)

        for dto in dtos {
            let group = existingGroupsDict[dto.id] ?? Group(context: context)
            if dto.isSoftDeleted {
                context.delete(group)
                continue
            }
            try group.update(from: dto, currencies: currenciesByCode, members: membersByID)
        }
    }

    private static func applyExpenseChanges(_ dtos: [Expense.DTO], in context: NSManagedObjectContext) throws {
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

    private static func applyCurrencyChanges(_ dtos: [Currency.DTO], in context: NSManagedObjectContext) throws {
        let existingCurrencies = try context.fetch(Currency.fetchRequest())
        let existingCurrenciesDict = Dictionary(uniqueKeysWithValues: existingCurrencies.compactMap { currency -> (String, Currency)? in
            guard let code = currency.c_code else { return nil }
            return (code, currency)
        })

        for dto in dtos {
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

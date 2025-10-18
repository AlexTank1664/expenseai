import SwiftUI
import CoreData

@main
struct expenseaiApp: App {
    // Создаем единственный экземпляр PersistenceController
    let persistenceController = DataController.shared
    
    // Создаем сервисы как @StateObject
    @StateObject private var authService = AuthService()
    // Инициализируем SyncEngine сразу при объявлении, передавая ему контекст
    // и сервис аутентификации.
    @StateObject private var syncEngine: SyncEngine
    @StateObject private var localizationManager = LocalizationManager()
    
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    
    init() {
        let authService = AuthService()
        let context = DataController.shared.container.viewContext
        _authService = StateObject(wrappedValue: authService)
        _syncEngine = StateObject(wrappedValue: SyncEngine(context: context, authService: authService))
        print("Core Data DB Path: \(NSPersistentContainer.defaultDirectoryURL())")
    }
    
    var body: some Scene {
        WindowGroup {
           
                
                ContentView()
                // Внедряем оба сервиса в окружение
                    .environmentObject(authService)
                    .environmentObject(syncEngine)
                // Также внедряем managedObjectContext для Core Data
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .preferredColorScheme(colorScheme == "dark" ? .dark : (colorScheme == "light" ? .light : nil))
                    .environmentObject(localizationManager)
            
        }
    }
}

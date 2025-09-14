//
//  codedta.swift
//  expenseai
//
//  Created by MacbookPro on 18.08.2025.
//
import Foundation
import CoreData

class DataController: ObservableObject {
    static let shared = DataController()
    
    let container: NSPersistentContainer
    

    
    init(inMemory: Bool = false) {
        // Убедитесь, что "Model" - это правильное имя вашего .xcdatamodeld файла
        container = NSPersistentContainer(name: "Model")
        
        // --- THE FIX IS HERE ---
        // Set the merge policy to allow in-memory changes to overwrite disk changes.
        // This is crucial for resolving conflicts during synchronization.
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
            
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        print(container.persistentStoreDescriptions.first?.url as Any)
    }
}
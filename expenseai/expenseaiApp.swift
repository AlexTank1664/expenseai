//
//  expenseaiApp.swift
//  expenseai
//
//  Created by MacbookPro on 18.08.2025.
//

import SwiftUI

@main
struct expenseaiApp: App {
    @StateObject private var dataController = DataController.shared
    @StateObject private var authService = AuthService()
    @AppStorage("colorScheme") private var colorScheme: String = "system"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.container.viewContext)
                .environmentObject(authService)
                .preferredColorScheme(colorScheme == "dark" ? .dark : (colorScheme == "light" ? .light : nil))
        }
    }
}
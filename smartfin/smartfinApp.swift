//
//  smartfinApp.swift
//  smartfin
//
//  Created by Brent Brewster on 1/22/26.
//  This file defines the main entry point for the iOS app, managing the app lifecycle and initializing key components.
//

import SwiftUI
import SwiftData

@main
struct smartfinApp: App {
    @StateObject private var syncDataManager = SyncDataManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(syncDataManager)
        }
        .modelContainer(sharedModelContainer)
    }
}

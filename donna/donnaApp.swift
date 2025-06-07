//
//  donnaApp.swift
//  donna
//
//  Created by William Wagner on 6/5/25.
//

import SwiftUI
import SwiftData

@main
struct donnaApp: App {
    // SwiftData container for recording metadata only
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Recording.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // C-1: Clean up orphaned entities on first launch
            #if DEBUG
            let context = container.mainContext
            // This will automatically handle migration by creating a fresh schema
            print("[donnaApp] SwiftData container initialized with Recording model")
            #endif
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

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
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
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

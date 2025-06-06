//
//  donnaApp.swift
//  donna
//
//  Created by William Wagner on 6/5/25.
//

import SwiftUI
import SwiftData
import AppIntents
import Foundation

@main
struct donnaApp: App {
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
    
    init() {
        print("[donnaApp] App initialized")
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                AudioRecordingManager.shared.stopRecording()
            },
            "DonnaRecordingStopped" as CFString,
            nil,
            .deliverImmediately
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if url.absoluteString == "donna://stopRecording" {
                        AudioRecordingManager.shared.stopRecording()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

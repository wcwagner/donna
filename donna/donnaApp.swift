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
import AVFoundation
import CoreFoundation

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
        
        // Configure audio session for background recording
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord,
                                  mode: .default,
                                  options: [.mixWithOthers, .defaultToSpeaker])
            print("[donnaApp] Audio session configured")
        } catch {
            print("[donnaApp] Failed to configure audio session: \(error)")
        }
        
        // Listen for start recording notifications
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    print("[donnaApp] Received start recording notification")
                    Task {
                        do {
                            try await recorderController.start()
                        } catch {
                            print("[donnaApp] Failed to start recording: \(error)")
                        }
                    }
                }
            },
            "DonnaStartRecording" as CFString,
            nil,
            .deliverImmediately
        )
        
        // Listen for stop recording notifications
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    print("[donnaApp] Received stop recording notification")
                    Task {
                        await recorderController.stop()
                    }
                }
            },
            "DonnaStopRecording" as CFString,
            nil,
            .deliverImmediately
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

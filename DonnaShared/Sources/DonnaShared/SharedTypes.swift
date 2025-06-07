//
//  SharedTypes.swift
//  Shared
//
//  Created by William Wagner on 6/5/25.
//

import ActivityKit
import Foundation
import AppIntents
import CoreFoundation
import OSLog

// MARK: - Darwin Notification Names

public let kDonnaStart = CFNotificationName("DonnaStartRecording" as CFString)
public let kDonnaStop = CFNotificationName("DonnaStopRecording" as CFString)

// MARK: - Live Activity Attributes

public struct DonnaRecordingAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        public var isRecording: Bool
        public var startDate: Date
        public var audioLevel: Double     // ← for waveform 0‥1

        public init(isRecording: Bool,
                    startDate: Date,
                    audioLevel: Double = 0) {
            self.isRecording = isRecording
            self.startDate = startDate
            self.audioLevel  = audioLevel
        }
    }

    public init() {}
}

// MARK: - Shared Intents

public struct StopRecordingIntent: AppIntent {
    public static let title: LocalizedStringResource = "Stop Recording"
    public static let description = IntentDescription("Stop the current recording")
    
    public static let openAppWhenRun: Bool = false
    
    // Debounce mechanism
    @MainActor
    private static var lastInvocation = Date.distantPast
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult {
        // Debounce rapid taps (1 second minimum between invocations)
        guard Date().timeIntervalSince(Self.lastInvocation) > 1.0 else {
            Log.intent.info("⏸️ StopRecordingIntent: Debounced duplicate stop request")
            return .result()
        }
        Self.lastInvocation = Date()
        
        if await AudioRecordingManager.shared.isRecording {
            // We ARE already in the recorder process ⇒ stop directly.
            Log.intent.info("🛑 Stop: direct call (same process)")
            await AudioRecordingManager.shared.stopRecording()
        } else {
            // Remote process ⇒ broadcast.
            Log.intent.info("📡 Stop: broadcasting to remote process")
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                kDonnaStop,
                nil, nil, true   // deliverImmediately
            )
        }
        
        return .result()
    }
}


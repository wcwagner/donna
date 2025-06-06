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

// MARK: - Darwin Notification Names

public let kDonnaStart = CFNotificationName("DonnaStartRecording" as CFString)
public let kDonnaStop = CFNotificationName("DonnaStopRecording" as CFString)

// MARK: - Live Activity Attributes

public struct DonnaRecordingAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        public var isRecording: Bool
        public var duration: TimeInterval
        public var audioLevel: Double     // ← for waveform 0‥1

        public init(isRecording: Bool,
                    duration: TimeInterval,
                    audioLevel: Double = 0) {
            self.isRecording = isRecording
            self.duration    = duration
            self.audioLevel  = audioLevel
        }
    }

    public init() {}
}

// MARK: - Shared Intents

public struct StopRecordingIntent: AppIntent {
    public static var title: LocalizedStringResource = "Stop Recording"
    public static var description = IntentDescription("Stop the current recording")
    
    public static var openAppWhenRun: Bool = false
    
    // Debounce mechanism
    @MainActor
    private static var lastInvocation = Date.distantPast
    
    public init() {}
    
    @MainActor
    public func perform() async throws -> some IntentResult {
        // Debounce rapid taps (1 second minimum between invocations)
        guard Date().timeIntervalSince(Self.lastInvocation) > 1.0 else {
            print("StopRecordingIntent: Debounced duplicate stop request")
            return .result()
        }
        Self.lastInvocation = Date()
        
        // Post Darwin notification that both app and widget can listen to
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            kDonnaStop,
            nil, nil, true
        )
        
        // Play haptic feedback for immediate user confirmation
        // Note: Haptic feedback is not available in widget extensions
        #if !WIDGET_EXTENSION
        if #available(iOS 17.5, *) {
            // This would work in the main app but not in widgets
        }
        #endif
        
        return .result()
    }
}
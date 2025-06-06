//
//  SharedTypes.swift
//  Shared
//
//  Created by William Wagner on 6/5/25.
//

import ActivityKit
import Foundation
import AppIntents

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
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        // Post Darwin notification that both app and widget can listen to
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("DonnaRecordingStopped" as CFString),
            nil, nil, true
        )
        return .result()
    }
}
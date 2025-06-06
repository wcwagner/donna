//
//  DonnaRecordingAttributes.swift
//  DonnaActivityWidget
//
//  Created by William Wagner on 6/5/25.
//

import ActivityKit
import Foundation

// Recording-specific Live Activity attributes (shared between app and widget)
public struct DonnaRecordingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Equatable {
        public var isRecording: Bool
        public var duration: TimeInterval
        
        public init(isRecording: Bool, duration: TimeInterval) {
            self.isRecording = isRecording
            self.duration = duration
        }
    }
    
    public init() {}
}
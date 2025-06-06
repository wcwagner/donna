//
//  StopRecordingIntent.swift
//  donna
//
//  Created by William Wagner on 6/5/25.
//

import AppIntents

struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Recording"
    static var description = IntentDescription("Stop the current recording")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        print("[StopRecordingIntent] Stopping recording")
        AudioRecordingManager.shared.stopRecording()
        return .result()
    }
}
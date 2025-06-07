//
//  RecordNoteIntent.swift
//  donna
//
//  Created by William Wagner on 6/5/25.
//

import AppIntents
import ActivityKit
import AVFoundation
import SwiftUI
import Foundation
import CoreFoundation
import DonnaShared


struct RecordNoteIntent: AudioRecordingIntent, LiveActivityStartingIntent, ForegroundContinuableIntent {
    static var title: LocalizedStringResource = "Donna note"
    static var description = IntentDescription("Start recording a note with Donna")
    
    // No UI - runs entirely in background
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        print("[RecordNoteIntent] Starting recording intent")
        print("[RecordNoteIntent] Process:", ProcessInfo.processInfo.processName)
        
        // Check microphone permission first
        let micPermission = AVAudioApplication.shared.recordPermission
        if micPermission == .undetermined {
            await AVAudioApplication.requestRecordPermission()
        }
        
        let micStatus = AVAudioApplication.shared.recordPermission
        guard AVAudioApplication.shared.recordPermission == .granted else {
            try await requestToContinueInForeground()
            return .result()
        }
        
        // Pre-flight check: Are Live Activities enabled?
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[RecordNoteIntent] Live Activities are disabled by user")
            // Continue recording without Live Activity
            let recordingId = UUID().uuidString
            try await AudioRecordingManager.shared.startRecording(activityId: recordingId)
            
            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
            
            return .result()
        }
        
        // N-3 Fix: Check for existing activity first
        let existingActivities = Activity<DonnaRecordingAttributes>.activities
        if !existingActivities.isEmpty {
            print("[RecordNoteIntent] Found \(existingActivities.count) existing activities")
            
            // End all existing activities before starting new one
            for activity in existingActivities {
                print("[RecordNoteIntent] Ending stale activity: \(activity.id)")
                await activity.end(dismissalPolicy: .immediate)
            }
            
            // Small delay to ensure activities are cleared
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Also check if AudioRecordingManager is already recording
        if await AudioRecordingManager.shared.isRecording {
            print("[RecordNoteIntent] AudioRecordingManager is already recording, stopping first")
            await AudioRecordingManager.shared.stopRecording()
            
            // Wait a bit for cleanup
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }
        
        // Generate unique ID for this recording
        let recordingId = UUID().uuidString
        
        // L-1 Fix: Request Live Activity BEFORE starting audio
        do {
            let initialState = DonnaRecordingAttributes.ContentState(
                isRecording: true,
                startDate: Date(),
                audioLevel: 0
            )
            
            let activityContent = ActivityContent(
                state: initialState,
                staleDate: nil
            )
            
            let activity = try Activity.request(
                attributes: DonnaRecordingAttributes(),
                content: activityContent,
                pushType: nil
            )
            
            print("[RecordNoteIntent] Live Activity started: \(activity.id)")
            
            // Minimal-start pattern: Start recording immediately
            try await AudioRecordingManager.shared.startRecording(activityId: activity.id)
            
            // Update activity to show recording state
            let recordingState = DonnaRecordingAttributes.ContentState(
                isRecording: true,
                startDate: Date(),
                audioLevel: 0
            )
            await activity.update(
                ActivityContent(state: recordingState, staleDate: nil)
            )
            
            // Stop notifications now handled via direct actor call in StopRecordingIntent
            
        } catch {
            print("[RecordNoteIntent] Failed to start Live Activity: \(error)")
            
            // If Live Activity fails, continue recording without it
            if error.localizedDescription.contains("visibility") {
                print("[RecordNoteIntent] Visibility error - continuing without Live Activity")
                
                do {
                    try await AudioRecordingManager.shared.startRecording(activityId: recordingId)
                    
                    // Provide haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                    
                    return .result()
                } catch {
                    print("[RecordNoteIntent] Recording failed even without Live Activity: \(error)")
                    return .result()
                }
            }
            
            throw error
        }
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        return .result()
    }
}

// App Shortcut for Action Button
struct DonnaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordNoteIntent(),
            phrases: [
                "Start a \(.applicationName) note",
                "Record with \(.applicationName)",
                "New \(.applicationName) note"
            ],
            shortTitle: "Donna note",
            systemImageName: "mic.circle"
        )
    }
}
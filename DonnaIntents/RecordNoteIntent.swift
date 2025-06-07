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
import OSLog


struct RecordNoteIntent: AudioRecordingIntent, ForegroundContinuableIntent {
    static var title: LocalizedStringResource = "Donna note"
    static var description = IntentDescription("Start recording a note with Donna")
    
    // No UI - runs entirely in background
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        Log.intent.info("↗️ RecordNoteIntent begin")
        let spState = Log.sp.beginInterval("Intent-to-Active")
        
        defer { Log.sp.endInterval("Intent-to-Active", spState) }
        
        Log.intent.info("📦 Process: \(ProcessInfo.processInfo.processName)")
        
        // Check microphone permission first
        let micPermission = AVAudioApplication.shared.recordPermission
        if micPermission == .undetermined {
            await AVAudioApplication.requestRecordPermission()
        }
        
        let micStatus = AVAudioApplication.shared.recordPermission
        Log.intent.info("🎤 Mic permission status: \(micStatus.rawValue)")
        guard AVAudioApplication.shared.recordPermission == .granted else {
            Log.intent.error("❌ Microphone access denied")
            throw DonnaError.micDenied
        }
        
        // Pre-flight check: Are Live Activities enabled?
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Log.intent.warning("⚠️ Live Activities are disabled by user")
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
            Log.intent.warning("🗑️ Found \(existingActivities.count) existing activities")
            
            // End all existing activities before starting new one
            for activity in existingActivities {
                Log.intent.info("🗑️ Ending stale activity: \(activity.id)")
                await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
            }
            
            // Small delay to ensure activities are cleared
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Also check if AudioRecordingManager is already recording
        if await AudioRecordingManager.shared.isRecording {
            Log.intent.warning("⚠️ AudioRecordingManager is already recording, stopping first")
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
            
            Log.intent.info("🚬 LiveActivity \(activity.id, privacy: .public) started")
            
            // Minimal-start pattern: Start recording immediately
            Log.intent.info("🎬 Starting AudioRecordingManager...")
            do {
                try await AudioRecordingManager.shared.startRecording(activityId: activity.id)
                Log.intent.info("✅ AudioRecordingManager started successfully")
            } catch RecordingError.startFailed {
                Log.intent.error("❌ record() returned false - throwing micBusy")
                throw DonnaError.micBusy
            }
            
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
            Log.intent.error("❌ Failed to start Live Activity: \(error)")
            
            // If Live Activity fails, continue recording without it
            if error.localizedDescription.contains("visibility") {
                Log.intent.warning("👁️ Visibility error - continuing without Live Activity")
                
                do {
                    try await AudioRecordingManager.shared.startRecording(activityId: recordingId)
                    
                    // Provide haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                    
                    return .result()
                } catch {
                    Log.intent.error("❌ Recording failed even without Live Activity: \(error)")
                    throw error
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

// Custom error types for better Shortcuts error messages
struct DonnaError: LocalizedError {
    let reason: ErrorReason
    
    enum ErrorReason {
        case micBusy
        case micDenied
    }
    
    static var micBusy: DonnaError { DonnaError(reason: .micBusy) }
    static var micDenied: DonnaError { DonnaError(reason: .micDenied) }
    
    var errorDescription: String? {
        switch reason {
        case .micBusy: 
            return "Microphone is still shutting down. Try again in a second."
        case .micDenied:
            return "Microphone access is required to record notes. Please enable in Settings."
        }
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
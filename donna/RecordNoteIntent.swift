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

struct RecordNoteIntent: AppIntent, ForegroundContinuableIntent, LiveActivityStartingIntent {
    static var title: LocalizedStringResource = "Donna note"
    static var description = IntentDescription("Start recording a note with Donna")
    
    // No UI - runs entirely in background
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        print("[RecordNoteIntent] Starting recording intent")
        
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
            await AudioRecordingManager.shared.startRecording(activityId: recordingId)
            
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
            await AudioRecordingManager.shared.startRecording(activityId: activity.id)
            
            // Update activity to show recording state
            let recordingState = DonnaRecordingAttributes.ContentState(
                isRecording: true,
                startDate: Date(),
                audioLevel: 0
            )
            await activity.update(
                ActivityContent(state: recordingState, staleDate: nil)
            )
            
            // Listen for stop notifications from the widget
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                nil,
                { _, _, _, _, _ in
                    Task {
                        await AudioRecordingManager.shared.stopRecording()
                    }
                },
                kDonnaStop.rawValue,
                nil,
                .coalesce
            )
            
        } catch {
            print("[RecordNoteIntent] Failed to start Live Activity: \(error)")
            
            // If Live Activity fails, continue recording without it
            if error.localizedDescription.contains("visibility") {
                print("[RecordNoteIntent] Visibility error - continuing without Live Activity")
                await AudioRecordingManager.shared.startRecording(activityId: recordingId)
                
                // Provide haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.prepare()
                impactFeedback.impactOccurred()
                
                return .result()
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


// Audio recording manager (singleton) - iOS 18 actor pattern
actor AudioRecordingManager {
    static let shared = AudioRecordingManager()
    
    // Actor-isolated state
    
    private var audioRecorder: AVAudioRecorder?
    private var audioRecorderDelegate: AudioRecorderDelegate?
    private var recordingTimer: Timer?
    private var currentActivityId: String?
    private var recordingStartTime: Date?
    private var smoothedLevel: Double = 0   // 0‥1 linear
    
    var isRecording: Bool {
        return audioRecorder?.isRecording ?? false
    }
    
    var currentRecordingId: String? {
        return currentActivityId
    }
    
    init() {
        Task {
            await setupAudioSession()
        }
    }
    
    private func linearLevel() -> Double {
        audioRecorder?.updateMeters()
        let db = audioRecorder?.averagePower(forChannel: 0) ?? -160
        let level = pow(10, Double(db) / 20)            // log → linear
        // One-pole low-pass filter (Voice-Memos-style)
        smoothedLevel = 0.2 * level + 0.8 * smoothedLevel
        return smoothedLevel
    }
    
    private func setupAudioSession() {
        let s = AVAudioSession.sharedInstance()
        do {
            try s.setCategory(.playAndRecord,
                              mode: .default,
                              options: [.mixWithOthers, .defaultToSpeaker])
            try s.setAllowHapticsAndSystemSoundsDuringRecording(true)
            try s.setActive(true)
            print("[AudioRecordingManager] Audio session configured for background mixing")
        } catch {
            print("[AudioRecordingManager] Failed to set up audio session: \(error)")
        }
    }
    
    func startRecording(activityId: String) async {
        print("[AudioRecordingManager] Starting recording for activity: \(activityId)")
        currentActivityId = activityId
        recordingStartTime = Date()
        
        // Configure audio recorder - use App Group container
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.williamwagner.donna") else {
            print("[AudioRecordingManager] Failed to get App Group container")
            return
        }
        let audioFilename = containerURL.appendingPathComponent("\(activityId).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorderDelegate = AudioRecorderDelegate()
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = audioRecorderDelegate
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            let recordingStarted = audioRecorder?.record() ?? false
            
            print("[AudioRecordingManager] Recording started: \(recordingStarted)")
            print("[AudioRecordingManager] Is recording: \(audioRecorder?.isRecording ?? false)")
            print("[AudioRecordingManager] Audio session input available: \(AVAudioSession.sharedInstance().isInputAvailable)")
            
            // Start monitoring for silence
            startSilenceDetection()
            
        } catch {
            print("[AudioRecordingManager] Failed to start recording: \(error)")
        }
    }
    
    private func startSilenceDetection() {
        // L-2 Fix: Update every 10 seconds instead of 0.25s
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 10.0,
                                              repeats: true) { _ in
            Task { [weak self] in
                guard let self = self else { return }
                guard let start = await self.recordingStartTime else { return }
                let dur = Date().timeIntervalSince(start)
                let level = await self.linearLevel()
                await self.updateLiveActivity(duration: dur, audioLevel: level)
            }
        }
    }
    
    @MainActor
    private func updateLiveActivity(duration: TimeInterval, audioLevel: Double = 0.0) async {
        guard let activityId = await currentActivityId,
              let startTime = await recordingStartTime else { return }
        let updatedState = DonnaRecordingAttributes.ContentState(
            isRecording: true,
            startDate: startTime,
            audioLevel: audioLevel
        )
        
        let activities = Activity<DonnaRecordingAttributes>.activities
        if let activity = activities.first(where: { $0.id == activityId }) {
            await activity.update(
                ActivityContent(state: updatedState, staleDate: nil)
            )
        }
    }
    
    func stopRecording() async {
        print("[AudioRecordingManager] Stopping recording")
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        audioRecorder?.stop()
        audioRecorder = nil
        audioRecorderDelegate = nil
        
        // End Live Activity
        if let activityId = currentActivityId {
            await endLiveActivity(activityId)
        }
        
        // Haptic feedback for recording ended
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        // Save recording metadata asynchronously
        if let startTime = recordingStartTime,
           let recordingId = currentActivityId {
            let duration = Date().timeIntervalSince(startTime)
            Task(priority: .utility) {
                await saveRecordingMetadata(id: recordingId, startDate: startTime, duration: duration)
            }
        }
        
        // TODO: Process with Whisper
        
        currentActivityId = nil
        recordingStartTime = nil
    }
    
    private func saveRecordingMetadata(id: String, startDate: Date, duration: TimeInterval) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.williamwagner.donna") else {
            print("[AudioRecordingManager] Failed to get App Group container for metadata")
            return
        }
        
        let audioFilePath = containerURL.appendingPathComponent("\(id).m4a").path
        
        // Store metadata in shared UserDefaults for now
        // Main app will sync this to SwiftData
        guard let userDefaults = UserDefaults(suiteName: "group.com.williamwagner.donna") else {
            print("[AudioRecordingManager] Failed to access shared UserDefaults")
            return
        }
        
        var recordings = userDefaults.dictionary(forKey: "recordings") ?? [:]
        recordings[id] = [
            "startDate": startDate,
            "duration": duration,
            "audioFilePath": audioFilePath
        ]
        userDefaults.set(recordings, forKey: "recordings")
        userDefaults.synchronize() // Force synchronization for cross-process access
    }
    
    @MainActor
    private func endLiveActivity(_ id: String) async {
        guard let activity = Activity<DonnaRecordingAttributes>
                .activities.first(where: { $0.id == id }) else { return }

        let stopState = DonnaRecordingAttributes.ContentState(
            isRecording: false,
            startDate: activity.content.state.startDate,
            audioLevel: 0
        )

        await activity.update(ActivityContent(state: stopState, staleDate: nil))
        try? await Task.sleep(for: .seconds(0.5))   // keep mic dot visible
        await activity.end(dismissalPolicy: .immediate)
    }
}

// Separate delegate class since actors can't conform to NSObject protocols
private class AudioRecorderDelegate: NSObject, AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder,
                                         successfully flag: Bool) {
        guard flag else { return }
        NotificationCenter.default.post(
            name: .donnaRecordingFinished,
            object: recorder.url
        )
    }
}

extension Notification.Name {
    static let donnaRecordingFinished = Self("donnaRecordingFinished")
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

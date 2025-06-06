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

struct RecordNoteIntent: AudioRecordingIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "Donna note"
    static var description = IntentDescription("Start recording a note with Donna")
    
    // No UI - runs entirely in background
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        print("[RecordNoteIntent] Starting recording intent")
        
        // Check if Live Activities are available
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[RecordNoteIntent] Live Activities are not enabled")
            // Start recording without Live Activity
            let recordingId = UUID().uuidString
            AudioRecordingManager.shared.startRecording(activityId: recordingId)
            await provideHapticFeedback()
            return .result()
        }
        
        // Start the Live Activity
        let attributes = DonnaRecordingAttributes()
        let initialState = DonnaRecordingAttributes.ContentState(isRecording: true, duration: 0)
        
        do {
            let activity = try Activity<DonnaRecordingAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            
            print("[RecordNoteIntent] Live Activity started with ID: \(activity.id)")
            
            // Start background audio recording
            AudioRecordingManager.shared.startRecording(activityId: activity.id)
            
            // Haptic feedback to confirm recording started
            await provideHapticFeedback()
            
        } catch {
            print("[RecordNoteIntent] Failed to start Live Activity: \(error)")
            // Fallback: Start recording without Live Activity
            let recordingId = UUID().uuidString
            AudioRecordingManager.shared.startRecording(activityId: recordingId)
            await provideHapticFeedback()
        }
        
        return .result()
    }
    
    private func provideHapticFeedback() async {
        // Gentle haptic to confirm recording started
        await MainActor.run {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }
}


// Audio recording manager (singleton)
class AudioRecordingManager: NSObject {
    static let shared = AudioRecordingManager()
    
    private var audioRecorder: AVAudioRecorder?
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
    
    private override init() {
        super.init()
        setupAudioSession()
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
    
    func startRecording(activityId: String) {
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
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            
            print("[AudioRecordingManager] Recording started")
            
            // Start monitoring for silence
            startSilenceDetection()
            
        } catch {
            print("[AudioRecordingManager] Failed to start recording: \(error)")
        }
    }
    
    private func startSilenceDetection() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.25,
                                              repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartTime else { return }
            let dur = Date().timeIntervalSince(start)
            Task { await self.updateLiveActivity(duration: dur,
                                                 audioLevel: self.linearLevel()) }
        }
    }
    
    @MainActor
    private func updateLiveActivity(duration: TimeInterval, audioLevel: Double = 0.0) async {
        guard let activityId = currentActivityId else { return }
        let updatedState = DonnaRecordingAttributes.ContentState(
            isRecording: true,
            duration: duration,
            audioLevel: audioLevel
        )
        
        let activities = Activity<DonnaRecordingAttributes>.activities
        if let activity = activities.first(where: { $0.id == activityId }) {
            await activity.update(
                ActivityContent(state: updatedState, staleDate: nil)
            )
        }
    }
    
    func stopRecording() {
        print("[AudioRecordingManager] Stopping recording")
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        // End Live Activity
        if let activityId = currentActivityId {
            Task {
                await endLiveActivity(activityId)
            }
        }
        
        // Haptic feedback for recording ended
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        
        // TODO: Store audio file in SQLite
        // TODO: Process with Whisper
        
        currentActivityId = nil
        recordingStartTime = nil
    }
    
    @MainActor
    private func endLiveActivity(_ id: String) async {
        guard let activity = Activity<DonnaRecordingAttributes>
                .activities.first(where: { $0.id == id }) else { return }

        let stopState = DonnaRecordingAttributes.ContentState(
            isRecording: false,
            duration: activity.content.state.duration,
            audioLevel: 0
        )

        await activity.update(ActivityContent(state: stopState, staleDate: nil))
        try? await Task.sleep(for: .seconds(0.5))   // keep mic dot visible
        await activity.end(dismissalPolicy: .immediate)
    }
}

extension AudioRecordingManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ r: AVAudioRecorder,
                                         successfully flag: Bool) {
        guard flag else { return }
        NotificationCenter.default.post(
            name: .donnaRecordingFinished,
            object: r.url
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

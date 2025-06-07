//
//  AudioRecordingManager.swift
//  DonnaShared
//
//  Audio recording manager for background recording from App Intents
//

import Foundation
import AVFoundation
import UIKit
import ActivityKit

public enum RecordingError: Error {
    case startFailed
    case noMicrophoneAccess
    case audioSessionError
}

// Audio recording manager (singleton) - iOS 18 actor pattern
public actor AudioRecordingManager {
    public static let shared = AudioRecordingManager()
    
    // Actor-isolated state
    private var audioRecorder: AVAudioRecorder?
    private var audioRecorderDelegate: AudioRecorderDelegate?
    private var recordingTimer: Timer?
    private var currentActivityId: String?
    private var recordingStartTime: Date?
    private var smoothedLevel: Double = 0   // 0‥1 linear
    
    public var isRecording: Bool {
        return audioRecorder?.isRecording ?? false
    }
    
    public var currentRecordingId: String? {
        return currentActivityId
    }
    
    init() {
        Task { 
            await setupAudioSession() 
        }
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, name, _, _ in
                guard name?.rawValue == kDonnaStop.rawValue else { return }
                Task { await AudioRecordingManager.shared.stopRecording() }
            },
            kDonnaStop.rawValue,
            nil,
            .deliverImmediately
        )
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
    
    public func startRecording(activityId: String) async throws {
        print("[AudioRecordingManager] Starting recording for activity: \(activityId)")
        currentActivityId = activityId
        recordingStartTime = Date()
        
        // Configure audio recorder - use App Group container
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupConfig.identifier) else {
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
            let prepareSuccess = audioRecorder?.prepareToRecord() ?? false
            let recordingStarted = audioRecorder?.record() ?? false
            
            print("[AudioRecordingManager] Prepare success: \(prepareSuccess)")
            print("[AudioRecordingManager] Recording started: \(recordingStarted)")
            print("[AudioRecordingManager] Is recording: \(audioRecorder?.isRecording ?? false)")
            print("[AudioRecordingManager] Audio session input available: \(AVAudioSession.sharedInstance().isInputAvailable)")
            
            // Fail fast if recording didn't start
            guard recordingStarted else {
                print("[AudioRecordingManager] ERROR: Failed to start recording - likely missing background audio mode")
                print("[AudioRecordingManager] This typically happens when running from Shortcuts without a proper App Intent Extension")
                
                // Clean up
                audioRecorder = nil
                audioRecorderDelegate = nil
                currentActivityId = nil
                recordingStartTime = nil
                
                // End the Live Activity with error state
                await endLiveActivity(activityId)
                
                throw RecordingError.startFailed
            }
            
            // Start monitoring for silence
            startSilenceDetection()
            
            // Failsafe auto-stop after 30 minutes
            Task.detached(priority: .background) { [currentActivityId] in
                try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000) // 30 minutes
                if await AudioRecordingManager.shared.currentRecordingId == currentActivityId {
                    print("[AudioRecordingManager] Auto-stopping after 30 minutes")
                    await AudioRecordingManager.shared.stopRecording()
                }
            }
            
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
                guard let activityId = await self.currentActivityId,
                      let startTime = await self.recordingStartTime else { return }
                let level = await self.linearLevel()
                await self.updateLiveActivity(activityId: activityId, startTime: startTime, audioLevel: level)
            }
        }
    }
    
    private func updateLiveActivity(activityId: String, startTime: Date, audioLevel: Double = 0.0) async {
        let updatedState = DonnaRecordingAttributes.ContentState(
            isRecording: true,
            startDate: startTime,
            audioLevel: audioLevel
        )
        
        await MainActor.run {
            let activities = Activity<DonnaRecordingAttributes>.activities
            if let activity = activities.first(where: { $0.id == activityId }) {
                Task {
                    await activity.update(
                        ActivityContent(state: updatedState, staleDate: nil)
                    )
                }
            }
        }
    }
    
    public func stopRecording() async {
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
        await MainActor.run {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
        
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
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupConfig.identifier) else {
            print("[AudioRecordingManager] Failed to get App Group container for metadata")
            return
        }
        
        let audioFilePath = containerURL.appendingPathComponent("\(id).m4a").path
        
        // Store metadata in shared UserDefaults for now
        // Main app will sync this to SwiftData
        guard let userDefaults = UserDefaults(suiteName: AppGroupConfig.identifier) else {
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
    
    private func endLiveActivity(_ id: String) async {
        await MainActor.run {
            guard let activity = Activity<DonnaRecordingAttributes>
                    .activities.first(where: { $0.id == id }) else { return }

            let stopState = DonnaRecordingAttributes.ContentState(
                isRecording: false,
                startDate: activity.content.state.startDate,
                audioLevel: 0
            )

            Task {
                await activity.update(ActivityContent(state: stopState, staleDate: nil))
                try? await Task.sleep(for: .seconds(0.5))   // keep mic dot visible
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}

// Separate delegate class since actors can't conform to NSObject protocols
private final class AudioRecorderDelegate: NSObject, AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder,
                                         successfully flag: Bool) {
        guard flag else { return }
        NotificationCenter.default.post(
            name: .donnaRecordingFinished,
            object: recorder.url
        )
    }
}

public extension Notification.Name {
    static let donnaRecordingFinished = Self("donnaRecordingFinished")
}
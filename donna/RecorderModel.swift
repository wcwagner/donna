//
//  RecorderModel.swift
//  donna
//
//  Created by William Wagner on 6/6/25.
//

import Foundation
import SwiftUI
import AVFoundation
import ActivityKit

// MARK: - Recording Phase

enum RecordingPhase: Equatable {
    case idle
    case starting
    case recording
}

// MARK: - Recorder Model (Observable State)

@Observable
@MainActor
final class RecorderModel {
    var phase: RecordingPhase = .idle
    var duration: TimeInterval = 0
    var audioLevel: Double = 0
    var currentActivityId: String?
    
    // Computed properties for UI
    var isRecording: Bool {
        phase == .recording
    }
    
    var state: RecordingPhase {
        phase
    }
}

// MARK: - Recorder Controller (Actor for thread-safe recording)

actor RecorderController {
    @MainActor private(set) var model = RecorderModel()
    
    private var phase: RecordingPhase = .idle
    private var audioRecorder: AVAudioRecorder?
    private var recordingStartTime: Date?
    private var updateTask: Task<Void, Never>?
    private var smoothedLevel: Double = 0
    
    init() {
        Task {
            await setupAudioSession()
        }
    }
    
    // MARK: - Public Interface
    
    func start() async throws {
        // Check phase with actor isolation
        guard phase == .idle else {
            print("[RecorderController] Start ignored - current phase: \(phase)")
            return
        }
        
        phase = .starting
        await MainActor.run {
            model.phase = .starting
        }
        
        do {
            // Start Live Activity first (system rule compliance)
            let activityId = await startLiveActivity()
            await MainActor.run {
                model.currentActivityId = activityId
            }
            
            // Configure audio session
            try await configureAudioSession()
            
            // Configure and start recorder
            let recorder = try await configureRecorder()
            recorder.record()
            
            self.audioRecorder = recorder
            self.recordingStartTime = Date()
            
            phase = .recording
            await MainActor.run {
                model.phase = .recording
                model.duration = 0
            }
            
            // Start update loop
            startUpdateLoop()
            
        } catch {
            phase = .idle
            await MainActor.run {
                model.phase = .idle
            }
            throw error
        }
    }
    
    func stop() async {
        // Check phase with actor isolation
        guard phase == .recording else {
            print("[RecorderController] Stop ignored - current phase: \(phase)")
            return
        }
        
        // Cancel update loop
        updateTask?.cancel()
        updateTask = nil
        
        // End Live Activity first (for clean UI transition)
        if let activityId = await model.currentActivityId {
            await endLiveActivity(activityId)
        }
        
        // Small delay for visual feedback
        try? await Task.sleep(for: .seconds(0.5))
        
        // Stop recording
        audioRecorder?.stop()
        audioRecorder = nil
        recordingStartTime = nil
        
        // Play haptic feedback
        await playHapticFeedback()
        
        phase = .idle
        await MainActor.run {
            model.phase = .idle
            model.duration = 0
            model.audioLevel = 0
            model.currentActivityId = nil
        }
        
        // Post notification that recording finished
        NotificationCenter.default.post(name: .donnaRecordingFinished, object: nil)
    }
    
    // MARK: - Private Helpers
    
    private func setupAudioSession() async {
        // Initial setup done once
    }
    
    private func configureAudioSession() async throws {
        let session = AVAudioSession.sharedInstance()
        
        // Check mic permission
        if #available(iOS 17.0, *) {
            guard AVAudioApplication.shared.recordPermission == .granted else {
                throw NSError(domain: "Donna", code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Microphone permission not granted"])
            }
        } else {
            // Fallback for iOS 16
            let hasPermission = await withCheckedContinuation { continuation in
                session.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            guard hasPermission else {
                throw NSError(domain: "Donna", code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Microphone permission not granted"])
            }
        }
        
        // Configure for background recording (same as Voice Memos)
        try session.setCategory(.playAndRecord,
                              mode: .default,
                              options: [.mixWithOthers, .defaultToSpeaker])
        try session.setActive(true)
    }
    
    private func configureRecorder() async throws -> AVAudioRecorder {
        // Use shared container for recordings
        guard let containerURL = AppGroupConfig.sharedContainerURL else {
            throw NSError(domain: "RecorderController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to access shared container"])
        }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let url = containerURL.appendingPathComponent("donna_\(timestamp).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        
        return recorder
    }
    
    private func startUpdateLoop() {
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                
                // Update duration and audio level
                if let startTime = await self.recordingStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    let level = await self.linearLevel()
                    
                    await MainActor.run {
                        self.model.duration = duration
                        self.model.audioLevel = level
                    }
                    
                    // Update Live Activity
                    if let activityId = await self.model.currentActivityId {
                        await self.updateLiveActivity(activityId, duration: duration, audioLevel: level)
                    }
                }
                
                // Update every 250ms
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }
    
    private func linearLevel() -> Double {
        audioRecorder?.updateMeters()
        let db = audioRecorder?.averagePower(forChannel: 0) ?? -160
        let level = pow(10, Double(db) / 20)
        // One-pole low-pass filter
        smoothedLevel = 0.2 * level + 0.8 * smoothedLevel
        return smoothedLevel
    }
    
    // MARK: - Live Activity Management
    
    private func startLiveActivity() async -> String? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
        
        let initialState = DonnaRecordingAttributes.ContentState(
            isRecording: true,
            duration: 0,
            audioLevel: 0
        )
        
        let content = ActivityContent(state: initialState, staleDate: nil)
        
        do {
            let activity = try Activity<DonnaRecordingAttributes>.request(
                attributes: DonnaRecordingAttributes(),
                content: content,
                pushType: nil
            )
            return activity.id
        } catch {
            print("Failed to start Live Activity: \(error)")
            return nil
        }
    }
    
    private func updateLiveActivity(_ id: String, duration: TimeInterval, audioLevel: Double) async {
        let state = DonnaRecordingAttributes.ContentState(
            isRecording: true,
            duration: duration,
            audioLevel: audioLevel
        )
        
        let content = ActivityContent(state: state, staleDate: nil)
        
        await Activity<DonnaRecordingAttributes>.activities
            .first(where: { $0.id == id })?
            .update(content)
    }
    
    private func endLiveActivity(_ id: String) async {
        let finalState = DonnaRecordingAttributes.ContentState(
            isRecording: false,
            duration: 0,
            audioLevel: 0
        )
        
        let content = ActivityContent(state: finalState, staleDate: nil)
        
        await Activity<DonnaRecordingAttributes>.activities
            .first(where: { $0.id == id })?
            .end(content, dismissalPolicy: .immediate)
    }
    
    private func playHapticFeedback() async {
        await MainActor.run {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - Global Recorder Instance

let recorderController = RecorderController()
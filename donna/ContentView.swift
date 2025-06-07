//
//  ContentView.swift
//  donna
//
//  Created by William Wagner on 6/5/25.
//

import SwiftUI
import SwiftData
import AVFoundation
import ActivityKit
import CoreFoundation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recording.startDate, order: .reverse) private var recordings: [Recording]
    @State private var isRecording = false
    @State private var currentRecordingId: String?
    
    var body: some View {
        NavigationView {
            List {
                Section("Status") {
                    if isRecording {
                        HStack {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.red)
                            Text("Recording in progress...")
                            Spacer()
                            Button(action: {
                                // Stop recording via Darwin notification
                                CFNotificationCenterPostNotification(
                                    CFNotificationCenterGetDarwinNotifyCenter(),
                                    CFNotificationName("DonnaStopRecording" as CFString),
                                    nil, nil, true
                                )
                            }) {
                                Label("Stop", systemImage: "stop.fill")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text("Use the Donna shortcut or Action Button to start recording")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Recordings") {
                    if recordings.isEmpty {
                        Text("No recordings yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(recordings) { recording in
                            RecordingRow(recording: recording)
                        }
                        .onDelete(perform: deleteRecordings)
                    }
                }
            }
            .navigationTitle("Donna")
        }
        .onAppear {
            syncRecordingsFromUserDefaults()
            checkActiveRecording()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            syncRecordingsFromUserDefaults()
            checkActiveRecording()
        }
        .task {
            // Periodically check for new recordings and active state
            while true {
                syncRecordingsFromUserDefaults()
                checkActiveRecording()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
    
    private func checkActiveRecording() {
        // Check if there's an active recording by looking at Live Activities
        let activities = Activity<DonnaRecordingAttributes>.activities
        isRecording = !activities.isEmpty
        currentRecordingId = activities.first?.id
    }
    
    private func syncRecordingsFromUserDefaults() {
        guard let userDefaults = UserDefaults(suiteName: "group.com.williamwagner.donna"),
              let recordingsDict = userDefaults.dictionary(forKey: "recordings") else {
            return
        }
        
        // Check each recording in UserDefaults
        for (id, value) in recordingsDict {
            guard let data = value as? [String: Any],
                  let startDate = data["startDate"] as? Date,
                  let duration = data["duration"] as? TimeInterval,
                  let audioFilePath = data["audioFilePath"] as? String else {
                continue
            }
            
            // Check if we already have this recording in SwiftData
            let existingRecording = recordings.first { $0.id == id }
            if existingRecording == nil {
                // Add new recording to SwiftData
                let recording = Recording(id: id, startDate: startDate, duration: duration, audioFilePath: audioFilePath)
                modelContext.insert(recording)
            }
        }
        
        try? modelContext.save()
    }
    
    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let recording = recordings[index]
            
            // Delete audio file
            if let url = URL(string: recording.audioFilePath) {
                try? FileManager.default.removeItem(at: url)
            }
            
            // Delete from SwiftData
            modelContext.delete(recording)
            
            // Remove from UserDefaults
            if let userDefaults = UserDefaults(suiteName: "group.com.williamwagner.donna") {
                var recordingsDict = userDefaults.dictionary(forKey: "recordings") ?? [:]
                recordingsDict.removeValue(forKey: recording.id)
                userDefaults.set(recordingsDict, forKey: "recordings")
            }
        }
        
        try? modelContext.save()
    }
}


struct RecordingRow: View {
    let recording: Recording
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioDelegate: AudioPlayerDelegate?
    @State private var playbackFinished = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(recording.startDate, style: .date)
                    .font(.headline)
                HStack {
                    Text(recording.startDate, style: .time)
                    Text("·")
                    Text(formatTime(recording.duration))
                    if recording.transcription != nil {
                        Text("·")
                        Image(systemName: "text.bubble")
                            .font(.caption)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .onChange(of: playbackFinished) { finished in
            if finished {
                isPlaying = false
                audioPlayer = nil
                audioDelegate = nil
                playbackFinished = false
            }
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.stop()
            isPlaying = false
            audioPlayer = nil
        } else {
            do {
                // Configure audio session for playback
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)
                
                // Convert file path string to proper file URL
                let url = URL(fileURLWithPath: recording.audioFilePath)
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                let delegate = AudioPlayerDelegate { 
                    DispatchQueue.main.async {
                        playbackFinished = true
                    }
                }
                audioDelegate = delegate
                audioPlayer?.delegate = audioDelegate
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                isPlaying = true
            } catch {
                print("Failed to play audio: \(error)")
            }
        }
    }
    
    private func formatTime(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t)/60, Int(t)%60)
    }
}

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let completion: () -> Void
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
        super.init()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completion()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Recording.self, inMemory: true)
}

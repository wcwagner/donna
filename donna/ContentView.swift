//
//  ContentView.swift
//  donna
//
//  Created by William Wagner on 6/5/25.
//

import SwiftUI
import SwiftData
import AVFoundation
import AVKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var recordings: [RecordingFile] = []
    @State private var recorderModel = recorderController.model
    
    var body: some View {
        NavigationView {
            List {
                Section("Actions") {
                    Button(action: toggleRecording) {
                        Label(recorderModel.isRecording ? "Stop Recording" : "Start Recording", 
                              systemImage: recorderModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .foregroundColor(recorderModel.isRecording ? .red : .blue)
                    }
                    .disabled(recorderModel.state == .starting)
                }
                
                Section("Recordings") {
                    if recordings.isEmpty {
                        Text("No recordings yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(recordings) { recording in
                            RecordingRow(recording: recording)
                        }
                        .onDelete(perform: deleteRecording)
                    }
                }
            }
            .navigationTitle("Donna")
            .toolbar {
                if recorderModel.state == .recording {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 4) {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text(formatDuration(recorderModel.duration))
                                .monospacedDigit()
                                .font(.caption)
                        }
                    }
                } else if recorderModel.state == .starting {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
        }
        .onAppear(perform: loadRecordings)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Reload when app comes to foreground
            loadRecordings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .donnaRecordingFinished)) { _ in
            loadRecordings()
        }
        .task {
            // Periodically reload recordings when not recording
            while true {
                if recorderModel.state == .idle {
                    loadRecordings()
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }
    
    private func toggleRecording() {
        Task {
            if recorderModel.state == .recording {
                await recorderController.stop()
            } else if recorderModel.state == .idle {
                try? await recorderController.start()
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func loadRecordings() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.williamwagner.donna") else {
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: containerURL, includingPropertiesForKeys: [.creationDateKey])
            recordings = files.compactMap { url in
                guard url.pathExtension == "m4a" else { return nil }
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                let creationDate = attributes?[.creationDate] as? Date ?? Date()
                
                let asset    = AVURLAsset(url: url)
                let duration = CMTimeGetSeconds(asset.duration)
                
                return RecordingFile(id: url.deletingPathExtension().lastPathComponent,
                                     url: url,
                                     creationDate: creationDate,
                                     duration: duration)
            }
            .sorted { $0.creationDate > $1.creationDate }
        } catch {
            print("Failed to load recordings: \(error)")
        }
    }
    
    private func deleteRecording(at offsets: IndexSet) {
        for index in offsets {
            let recording = recordings[index]
            try? FileManager.default.removeItem(at: recording.url)
        }
        loadRecordings()
    }
}

struct RecordingFile: Identifiable {
    let id: String
    let url: URL
    let creationDate: Date
    let duration: TimeInterval      // ← new
}

struct RecordingRow: View {
    let recording: RecordingFile
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioDelegate: AudioPlayerDelegate?
    @State private var playbackFinished = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(recording.creationDate, style: .date)
                    .font(.headline)
                HStack {
                    Text(recording.creationDate, style: .time)
                    Text("·")
                    Text(formatTime(recording.duration))
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
                
                audioPlayer = try AVAudioPlayer(contentsOf: recording.url)
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
        .modelContainer(for: Item.self, inMemory: true)
}

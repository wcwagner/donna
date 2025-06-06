//
//  ContentView.swift
//  donna
//
//  Created by William Wagner on 6/5/25.
//

import SwiftUI
import SwiftData
import AVFoundation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var recordings: [RecordingFile] = []
    @State private var isRecording = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Actions") {
                    Button(action: toggleRecording) {
                        Label(isRecording ? "Stop Recording" : "Start Recording", 
                              systemImage: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .foregroundColor(isRecording ? .red : .blue)
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
                        .onDelete(perform: deleteRecording)
                    }
                }
            }
            .navigationTitle("Donna")
            .toolbar {
                if isRecording {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Text("Recording...")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
        }
        .onAppear(perform: loadRecordings)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            updateRecordingState()
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            AudioRecordingManager.shared.stopRecording()
        } else {
            let recordingId = UUID().uuidString
            AudioRecordingManager.shared.startRecording(activityId: recordingId)
        }
        updateRecordingState()
        
        // Reload recordings after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            loadRecordings()
        }
    }
    
    private func updateRecordingState() {
        isRecording = AudioRecordingManager.shared.isRecording
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
                return RecordingFile(id: url.deletingPathExtension().lastPathComponent,
                                   url: url,
                                   creationDate: creationDate)
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
}

struct RecordingRow: View {
    let recording: RecordingFile
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(recording.creationDate, style: .date)
                    .font(.headline)
                Text(recording.creationDate, style: .time)
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
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.stop()
            isPlaying = false
        } else {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: recording.url)
                audioPlayer?.delegate = AudioPlayerDelegate { [self] in
                    isPlaying = false
                }
                audioPlayer?.play()
                isPlaying = true
            } catch {
                print("Failed to play audio: \(error)")
            }
        }
    }
}

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let completion: () -> Void
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completion()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

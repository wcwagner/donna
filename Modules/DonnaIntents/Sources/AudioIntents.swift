import AppIntents
import DonnaShared
import ActivityKit

struct StartRecordingIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Start Recording"
    static var parameterSummary: some ParameterSummary {
        Summary("Start a new recording in Donna")
    }
    
    @Dependency var audioRecorder: AudioRecordingService
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let token = try await audioRecorder.start()
        
        // Create Live Activity HERE, not in recorder
        let activity = try Activity<RecordingActivityAttributes>.request(
            attributes: RecordingActivityAttributes(sessionId: token.id),
            contentState: RecordingActivityAttributes.ContentState(
                startTime: Date(),
                isPaused: false,
                rms: []
            )
        )
        
        return .result(value: activity.id)
    }
}

// Parameter-less stop intent for hardware triggers
struct StopCurrentRecordingIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Stop Current Recording"
    static var parameterSummary: some ParameterSummary {
        Summary("Stop the current recording")
    }
    
    @Dependency var audioRecorder: AudioRecordingService
    
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        if let recording = try await audioRecorder.stopCurrent() {
            return .result() {
                RecordingCompleteView(recording: recording)
            }
        } else {
            return .result() {
                Text("No active recording")
            }
        }
    }
}



// Register shortcuts for discovery
struct DonnaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Start recording in \(.applicationName)",
                "\(.applicationName) start recording"
            ],
            shortTitle: "Start Recording",
            systemImageName: "mic.circle"
        )
        
        // Parameter-less for hardware
        AppShortcut(
            intent: StopCurrentRecordingIntent(),
            phrases: [
                "Stop recording in \(.applicationName)",
                "\(.applicationName) stop recording"
            ],
            shortTitle: "Stop Recording",
            systemImageName: "stop.circle"
        )
    }
}
import DonnaCore
import DonnaShared

@main
struct DonnaApp: App {
    init() {
        AppDependencyManager.shared.register(AudioRecordingService.self) {
            AudioRecorderManager()
        }
    }
    // … default SwiftUI boilerplate …
}
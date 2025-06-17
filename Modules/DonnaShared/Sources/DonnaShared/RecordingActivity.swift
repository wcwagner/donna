import ActivityKit
import Foundation

public struct RecordingActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable {
        public var startTime: Date
        public var isPaused: Bool
        public var rms: [UInt8] // Max 32 samples
    }
    let sessionId: UUID
}


public actor RecordingLiveActivityManager: Sendable {
    private var current: Activity<RecordingActivityAttributes>?


    func start(sessionID: UUID) async throws -> Activity.ID {
        // If somehow an activity is still alive, end it first to stay within system limits.
        if let activity = current { await activity.end(dismissalPolicy: .immediate) }

        let activity = try Activity<RecordingActivityAttributes>.request(
            attributes: .init(sessionId: sessionID),
            contentState: .init(startTime: .now, isPaused: false, rms: [])
        )
        current = activity
        return activity.id
    }

    func end() async {
        if let activity = current {
            await activity.end(dismissalPolicy: .immediate)
            current = nil
        }
    }
}
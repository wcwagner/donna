import ActivityKit
import WidgetKit
import SwiftUI
import DonnaShared

struct DonnaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            VStack {
                Image(systemName: "mic.fill")
                Text(timerInterval: context.state.startTime ... .distantFuture)
                    .monospacedDigit()
            }
            .padding()
        } dynamicIsland: { _ in
            DynamicIsland { } compactLeading: { Image(systemName: "mic") }
                              compactTrailing: { }
                              minimal: { Image(systemName: "mic") }
        }
    }
}

@main
struct DonnaWidgetBundle: WidgetBundle {
    var body: some Widget {
        DonnaLiveActivity()
    }
}
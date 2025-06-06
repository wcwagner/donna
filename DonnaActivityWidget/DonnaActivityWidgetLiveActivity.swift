//
//  DonnaActivityWidgetLiveActivity.swift
//  DonnaActivityWidget
//
//  Created by William Wagner on 6/5/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct DonnaActivityWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct DonnaActivityWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DonnaActivityWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

// Recording Live Activity
struct DonnaRecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DonnaRecordingAttributes.self) { context in
            // Lock screen/banner UI goes here
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recording...")
                    Text("Tap to stop")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(formatDuration(context.state.duration))
                    .monospacedDigit()
            }
            .padding()
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.white)
            .widgetURL(URL(string: "donna://stopRecording"))

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.red)
                                .font(.title2)
                            Text("Recording")
                                .font(.headline)
                        }
                        
                        // Audio level indicator
                        Capsule()
                            .fill(context.state.audioLevel > 0.7 ? .orange : .green)
                            .frame(width: 60 * context.state.audioLevel, height: 6)
                            .animation(.easeInOut(duration: 0.1), value: context.state.audioLevel)
                            .frame(maxWidth: 60, alignment: .leading)
                            .background(
                                Capsule().fill(Color.gray.opacity(0.3))
                            )
                        
                        Text("Tap to stop")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(formatDuration(context.state.duration))
                        .font(.largeTitle)
                        .monospacedDigit()
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
            } compactTrailing: {
                Text(formatDuration(context.state.duration))
                    .monospacedDigit()
                    .frame(minWidth: 45)
            } minimal: {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
            }
            .keylineTint(Color.red)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension DonnaActivityWidgetAttributes {
    fileprivate static var preview: DonnaActivityWidgetAttributes {
        DonnaActivityWidgetAttributes(name: "World")
    }
}

extension DonnaActivityWidgetAttributes.ContentState {
    fileprivate static var smiley: DonnaActivityWidgetAttributes.ContentState {
        DonnaActivityWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: DonnaActivityWidgetAttributes.ContentState {
         DonnaActivityWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: DonnaActivityWidgetAttributes.preview) {
   DonnaActivityWidgetLiveActivity()
} contentStates: {
    DonnaActivityWidgetAttributes.ContentState.smiley
    DonnaActivityWidgetAttributes.ContentState.starEyes
}

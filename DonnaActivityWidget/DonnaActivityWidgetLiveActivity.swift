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

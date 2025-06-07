//
//  DonnaActivityWidgetLiveActivity.swift
//  DonnaActivityWidget
//
//  Created by William Wagner on 6/5/25.
//

import ActivityKit
import WidgetKit
import SwiftUI
import DonnaShared

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
                Text(timerInterval: context.state.startDate...Date(),
                     countsDown: false,
                     showsHours: false)
                    .monospacedDigit()
            }
            .padding()
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.white)

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
                        
                        // Interactive stop button
                        Button(intent: StopRecordingIntent()) {
                            Label("Stop Recording", systemImage: "stop.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(timerInterval: context.state.startDate...Date.distantFuture,
                         showsHours: false)
                        .font(.largeTitle)
                        .monospacedDigit()
                }
            } compactLeading: {
                Button(intent: StopRecordingIntent()) {
                    Image(systemName: "stop.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            } compactTrailing: {
                Text(timerInterval: context.state.startDate...Date(),
                     countsDown: false,
                     showsHours: false)
                    .monospacedDigit()
                    .frame(minWidth: 45)
            } minimal: {
                Button(intent: StopRecordingIntent()) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            .keylineTint(Color.red)
        }
    }
}

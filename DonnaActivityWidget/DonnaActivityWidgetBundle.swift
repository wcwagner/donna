//
//  DonnaActivityWidgetBundle.swift
//  DonnaActivityWidget
//
//  Created by William Wagner on 6/5/25.
//

import WidgetKit
import SwiftUI
import AppIntents

@main
struct DonnaActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        DonnaActivityWidget()
        DonnaActivityWidgetControl()
        DonnaRecordingLiveActivity()
    }
}

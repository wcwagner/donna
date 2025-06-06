//
//  Recording.swift
//  donna
//
//  Created by Claude on 6/6/25.
//

import Foundation
import SwiftData

@Model
final class Recording {
    var id: String
    var startDate: Date
    var duration: TimeInterval
    var audioFilePath: String
    var transcription: String?
    var transcriptionDate: Date?
    
    init(id: String, startDate: Date, duration: TimeInterval, audioFilePath: String) {
        self.id = id
        self.startDate = startDate
        self.duration = duration
        self.audioFilePath = audioFilePath
    }
}
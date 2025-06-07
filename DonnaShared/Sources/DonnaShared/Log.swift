//
//  Log.swift
//  DonnaShared
//
//  Unified logging for all Donna targets
//

import OSLog

public enum Log {
    public static let intent  = Logger(subsystem: "com.williamwagner.donna", category: "intent")
    public static let audio   = Logger(subsystem: "com.williamwagner.donna", category: "audio")
    public static let widget  = Logger(subsystem: "com.williamwagner.donna", category: "widget")
    public static let app     = Logger(subsystem: "com.williamwagner.donna", category: "app")
    
    // Signposter for timing
    public static let sp = OSSignposter(subsystem: "com.williamwagner.donna.record", category: "pipeline")
}

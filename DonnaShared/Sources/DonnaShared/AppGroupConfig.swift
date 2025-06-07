//
//  AppGroupConfig.swift
//  donna
//
//  Created by William Wagner on 6/5/25.
//

import Foundation

public struct AppGroupConfig {
    public static let identifier = "group.com.williamwagner.donna"
    
    public static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
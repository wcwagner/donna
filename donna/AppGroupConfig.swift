//
//  AppGroupConfig.swift
//  donna
//
//  Created by William Wagner on 6/5/25.
//

import Foundation

struct AppGroupConfig {
    static let identifier = "group.com.williamwagner.donna"
    
    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
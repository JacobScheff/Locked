//
//  ModelContainer+Ext.swift
//  Locked
//
//  Created by Jacob Scheff on 4/10/26.
//

import Foundation
import SwiftData

extension ModelContainer {
    static let sharedLockedApp: ModelContainer = {
        let schema = Schema([ScreenTime.self])
        
        // Ensure SwiftData uses your shared App Group container
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.Jacob-Scheff.Locked")!
        let dbURL = groupURL.appendingPathComponent("Locked.sqlite")
        
        let modelConfiguration = ModelConfiguration(schema: schema, url: dbURL)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    static func forLockedApp() -> ModelContainer {
        return sharedLockedApp
    }
}

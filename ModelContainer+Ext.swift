//
//  ModelContainer+Ext.swift
//  Locked
//
//  Created by Jacob Scheff on 4/10/26.
//

import Foundation
import SwiftData

extension ModelContainer {
    // A shared singleton to ensure the App and Intents use the exact same DB connection
    static let sharedLockedApp: ModelContainer = {
        let schema = Schema([
            ScreenTime.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    // The method your AppIntent is looking for
    static func forLockedApp() -> ModelContainer {
        return sharedLockedApp
    }
}

//
//  LockedApp.swift
//  Locked
//
//  Created by Jacob Scheff on 4/10/26.
//

import SwiftUI
import SwiftData
import AppIntents

@main
struct LockedApp: App {
    init() {
        LibraryAppShortcuts.updateAppShortcutParameters()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(ModelContainer.forLockedApp())
    }
}

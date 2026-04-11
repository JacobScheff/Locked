//
//  Shortcuts.swift
//  Locked
//
//  Created by Jacob Scheff on 4/10/26.
//

import Foundation
import AppIntents
import SwiftData

struct LibraryAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OnAppOpen(),
            phrases: ["On ${applicationName} Open"],
            systemImageName: "checkmark.circle"
        )
        
        AppShortcut(
            intent: OnAppClose(),
            phrases: [
                "On \(.applicationName) Close"
            ],
            systemImageName: "xmark.circle"
        )
    }
}

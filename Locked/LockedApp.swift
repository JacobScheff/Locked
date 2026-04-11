//
//  LockedApp.swift
//  Locked
//
//  Created by Jacob Scheff on 4/10/26.
//

import SwiftUI
import SwiftData

@main
struct LockedApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Use the extension here too!
        .modelContainer(ModelContainer.forLockedApp())
    }
}

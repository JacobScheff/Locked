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
    @StateObject private var lockScheduler = LockScheduler()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.lockedIndigo)
                .fontDesign(.rounded)
                .environmentObject(ScreenTimeManager.shared)
                .onAppear {
                    lockScheduler.start()
                    ScreenTimeManager.shared.refreshStatus()
                }
                .onDisappear { lockScheduler.stop() }
        }
    }
}

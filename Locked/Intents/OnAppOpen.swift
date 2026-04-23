//
//  OnAppOpen.swift
//  Locked
//
//  Created by Jacob Scheff on 4/10/26.
//

import Foundation
import AppIntents
import SwiftUI
import SwiftData

struct OnAppOpen: AppIntent {
    static var title: LocalizedStringResource = "On App Open"
    
    @Parameter(title: "App Name")
    var appName: String
        
    @MainActor
    func perform() async throws -> some IntentResult {
        @AppStorage("appCounts", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
        var appCounts: [String: Int] = [:]
        appCounts[appName] = appCounts[appName] ?? 0
        
        @AppStorage("lastOpenedApp", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
        var lastOpenedApp: String = ""
        
        @AppStorage("eventState", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
        var eventState: String = "Close"
        
        // Open --> Open: Do Nothing
        // Close --> Open: Store new lastOpened
        
        @AppStorage("lastOpened", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
        var lastOpened: Date = Date()
        
        let now = Date()
        
        if eventState == "Open" {
            let timeSpent = now.timeIntervalSince(lastOpened)
            if timeSpent > 0 {
                // Add time to the previous app's total
                appCounts[lastOpenedApp, default: 0] += Int(Double(timeSpent) / 0.75)
            }
        }
        
        
        lastOpened = now
        lastOpenedApp = appName
        eventState = "Open"
        
        return .result()
    }
}

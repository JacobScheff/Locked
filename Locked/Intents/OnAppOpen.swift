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
        appCounts[appName] = (appCounts[appName] ?? 0) + 1

        @AppStorage("eventState", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
        var eventState: String = "closed"
        
        // Open --> Open: Do Nothing
        // Close --> Open: Store new lastOpened
        
        if eventState == "Open" {
            return .result()
        }
        
        @AppStorage("lastOpened", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
        var lastOpened: Date = Date()
                
        lastOpened = Date()
        eventState = "Open"
                
        return .result()
    }
}

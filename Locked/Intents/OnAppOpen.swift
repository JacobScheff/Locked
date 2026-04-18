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
        @AppStorage("startTimes", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
        var startTimes: [Date] = []
        
        @AppStorage("appCounts", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
        var appCounts: [String: Int] = [:]
        
        let startTime: Date = Date()
        
        startTimes.append(startTime)
        appCounts[appName] = (appCounts[appName] ?? 0) + 1
        
        return .result()
    }
}

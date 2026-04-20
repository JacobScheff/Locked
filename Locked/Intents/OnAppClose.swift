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

struct OnAppClose: AppIntent {
    static var title: LocalizedStringResource = "On App Close"
        
    @MainActor
    func perform() async throws -> some IntentResult {
        @AppStorage("eventState", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
        var eventState: String = "closed"
        
        // Open --> Close: time += e - s
        // Close --> Close: Do Nothing
        
        if eventState == "Close" {
            return .result()
        }
        
        @AppStorage("lastOpened", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
        var lastOpened: Date = Date()
        
        @AppStorage("screentime", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
        var screentime: Int = 0
        
        // 25% chance of Close-->Close. In this case, data is lost. So, divide by 0.75 to account for this
        screentime += Int(Double(Date().timeIntervalSince(lastOpened)) / 0.75)
    
        eventState = "Close"

        return .result()
    }
}

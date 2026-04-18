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
        @AppStorage("startTimes", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
        var startTimes: [Date] = []
        
        var startTime = startTimes.popLast()
        
        if startTime != nil {
            @AppStorage("screentime", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
            var screentime: Int = 0
            
            screentime += Int(Date().timeIntervalSince(startTime!))
        }
        
        return .result()
    }
}

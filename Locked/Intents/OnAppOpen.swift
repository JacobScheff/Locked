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
        
    @MainActor
    func perform() async throws -> some IntentResult {
        @AppStorage("startTimes", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
        var startTimes: [Date] = []
        
        startTimes.append(Date())
        
        return .result()
    }
}

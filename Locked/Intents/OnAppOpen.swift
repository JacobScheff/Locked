import Foundation
import AppIntents
import SwiftUI

struct OnAppOpen: AppIntent {
    static var title: LocalizedStringResource = "On App Open"
    
    @Parameter(title: "App Name")
    var appName: String
        
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let store = LogicStore.shared
        
        // 1. Check if the app is locked
        if store.lockedApps.contains(appName) {
            // Returns 'true' so the Shortcuts app knows to execute "Go to Home Screen"
            return .result(value: true)
        }
        
        // 2. Track screen time
        store.appCounts[appName] = store.appCounts[appName] ?? 0
        let now = Date()
        
        if store.eventState == "Open" {
            let timeSpent = now.timeIntervalSince(store.lastOpened)
            if timeSpent > 0 {
                // Add time to the previous app's total
                store.appCounts[store.lastOpenedApp, default: 0] += Int(Double(timeSpent) / 0.75)
            }
        }
        
        store.lastOpened = now
        store.lastOpenedApp = appName
        store.eventState = "Open"
        
        return .result(value: false)
    }
}

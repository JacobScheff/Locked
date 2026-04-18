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
        @AppStorage("openedApp", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
        var openedApp: String = ""
        
        let container = ModelContainer.forLockedApp()
        let context = container.mainContext
        
        let name = appName
        openedApp = name
        
        let fetchDescriptor = FetchDescriptor<ScreenTime>(
            predicate: #Predicate { $0.appName == name }
        )
        
        do {
            let results = try context.fetch(fetchDescriptor)
            
            if let existingApp = results.first {
                existingApp.lastOpened = Date()
            } else {
                let newApp = ScreenTime(appName: name)
                newApp.lastOpened = Date()
                context.insert(newApp)
            }
            
            try context.save()
            
        } catch {
            print("Failed to fetch or save ScreenTime: \(error)")
        }
        
        return .result()
    }
}

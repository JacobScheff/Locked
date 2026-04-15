//
//  OnAppOpen.swift
//  Locked
//
//  Created by Jacob Scheff on 4/10/26.
//

import Foundation
import AppIntents
import SwiftData

struct OnAppClose: AppIntent {
    static var title: LocalizedStringResource = "On App Close"
    
    @Parameter(title: "App Name")
    var appName: String
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let name = appName
        guard !name.isEmpty else { return .result() }

        let container = ModelContainer.forLockedApp()
        let context = container.mainContext
                
        let fetchDescriptor = FetchDescriptor<ScreenTime>(
            predicate: #Predicate { $0.appName == name }
        )
        
        do {
            let results = try context.fetch(fetchDescriptor)
            
            if let existingApp = results.first {
                let passedTime = Date().timeIntervalSince(existingApp.lastOpened)
                
                if passedTime > 0 {
                    existingApp.totalScreenTime += passedTime
                }
                
                existingApp.lastOpened = Date()
            }
            
            try context.save()
            
        } catch {
            print("Failed to fetch or save ScreenTime: \(error)")
        }
        
        return .result()
    }
}

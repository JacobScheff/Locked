//
//  OnAppOpen.swift
//  Locked
//
//  Created by Jacob Scheff on 4/10/26.
//

import Foundation
import AppIntents
import SwiftData

struct OnAppOpen: AppIntent {
    static var title: LocalizedStringResource = "On App Open"
    
    @Parameter(title: "App Name")
    var appName: String
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // This will now compile successfully!
        let container = ModelContainer.forLockedApp()
        let context = container.mainContext
        
        // Assign to a local variable (prevents macro capturing errors in #Predicate)
        let name = appName
        
        let fetchDescriptor = FetchDescriptor<ScreenTime>(
            predicate: #Predicate { $0.appName == name }
        )
        
        do {
            let results = try context.fetch(fetchDescriptor)
            
            if let existingApp = results.first {
                // App exists in DB -> update the lastOpened time
                existingApp.lastOpened = Date()
            } else {
                // App doesn't exist -> create new entry and insert it
                let newApp = ScreenTime(appName: name)
                newApp.lastOpened = Date()
                context.insert(newApp)
            }
            
            // Save the context
            try context.save()
            
        } catch {
            print("Failed to fetch or save ScreenTime: \(error)")
        }
        
        return .result()
    }
}

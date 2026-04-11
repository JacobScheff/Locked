//
//  Screentime.swift
//  Locked
//
//  Created by Jacob Scheff on 4/10/26.
//

import Foundation
import SwiftData

@Model
final class ScreenTime {
    var appName: String
    var lastOpened: Date?
    var totalScreenTime: Double
    
    init(appName: String) {
        self.appName = appName
        self.totalScreenTime = 0
    }
}

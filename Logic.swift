//
//  Logic.swift
//  Locked
//
//  Created by Jacob Scheff on 4/20/26.
//

import Foundation
import SwiftUI

func updateKarma(completionDate: Double, dueDate: Double, a: Double, b: Double, c: Double) {
    let term1: Double = b / abs(a - dueDate / b) / pow(dueDate, 2)
    let term2: Double = pow((Double(dueDate) / c - completionDate), 3)
    let delta: Double = term1 * term2
    
    @AppStorage("karma", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var karma: Double = 0.0
    
    karma += delta
}

func unlockApp(numLockedApps: Int, usagePercentage: Double) {
    let cost = pow(Double(numLockedApps), 1.5) + 0.5 * pow(usagePercentage, 1.25) + 10.0
    
    @AppStorage("keys", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var keys: Double = 0.0
    
    keys -= cost
}

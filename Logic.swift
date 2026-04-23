//
//  Logic.swift
//  Locked
//
//  Created by Jacob Scheff on 4/20/26.
//

import Foundation
import SwiftUI
import GameplayKit

func updateKarma(assignedDate: Double, dueDate: Double, daysTakenForCompletiion: Double, S: Double, a: Double) {
    var w: Double = (daysTakenForCompletiion - assignedDate) / (dueDate - assignedDate)
    
    let term1: Double = S / abs(S - dueDate / a) / pow(dueDate, 2)
    let term2: Double = pow((Double(dueDate) * w - (daysTakenForCompletiion - assignedDate)), 3)
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

func getZScoreFromKarma() -> Double {
    // Karma = 100: z-score = 3
    // Karma = 50: z-score = 0
    // Karma = 0: z-score = -3
    
    @AppStorage("karma", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var karma: Double = 0.0
    
    return -0.06 * karma + 3
}

func lockAppByKarma() -> String {
    @AppStorage("appCounts", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var appCounts: [String: Int] = [:]
    
    guard !appCounts.isEmpty else { return "" }
    
    // Sort apps from lowest frequency to highest frequency
    let sortedApps = appCounts.sorted { $0.value < $1.value }
    let totalFrequency = sortedApps.reduce(0) { $0 + $1.value }
    
    // Setup the GKGaussianDistribution
    let precision: Float = 1000.0
    let meanZScore = Float(getZScoreFromKarma())
    
    let distribution = GKGaussianDistribution(
        randomSource: GKARC4RandomSource(),
        mean: meanZScore * precision,
        deviation: 1.0 * precision
    )
    
    // Generate the Gaussian random number and strip the multiplier back off
    let zRand = Double(distribution.nextInt()) / Double(precision)
    
    // Map the Z-Score from a [-3.0, 3.0] window to a percentage [0.0, 1.0]
    // High Karma (Mean -3) generates values generally <= 0, clamping to 0.0 (Least Used Apps)
    // Low Karma (Mean 3) generates values generally >= 1.0, clamping to 1.0 (Most Used Apps)
    var normalizedPosition = (zRand + 3.0) / 6.0
    normalizedPosition = max(0.0, min(1.0, normalizedPosition))
    
    // Convert percentage into our cumulative frequency domain
    let targetCumulativeFrequency = normalizedPosition * Double(totalFrequency)
    
    // Iterate through the sorted frequencies to find the target app
    var currentCumulative = 0.0
    var appToLock = sortedApps.last!.key // Fallback securely to highest used app
    
    for app in sortedApps {
        currentCumulative += Double(app.value)
        
        if currentCumulative >= targetCumulativeFrequency {
            appToLock = app.key
            break
        }
    }
    
    // TODO: Actually lock the chosen app
    return appToLock
//    print("Based on Karma, locking app: \(appToLock)")
}

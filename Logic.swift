//
//  Logic.swift
//  Locked
//

import Foundation
import SwiftUI
import GameplayKit
import Combine

// MARK: - Karma

/// assignedDate, dueDate, daysTakenForCompletion are all in fractional days since epoch.
func updateKarma(assignedDate: Double, dueDate: Double, daysTakenForCompletion: Double, S: Double, a: Double) {
    let w: Double = (daysTakenForCompletion - assignedDate) / (dueDate - assignedDate)

    let term1: Double = S / abs(S - dueDate / a) / pow(dueDate, 2)
    let term2: Double = pow(Double(dueDate) * w - (daysTakenForCompletion - assignedDate), 3)
    let delta: Double = term1 * term2

    @AppStorage("karma", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var karma: Double = 0.0
    karma += delta
}

/// Convenience wrapper that accepts Swift Dates and converts them to fractional days.
func updateKarmaForAssignment(releaseDate: Date, dueDate: Date, completionDate: Date) {
    let dayScale: Double = 86_400          // seconds per day
    let assigned = releaseDate.timeIntervalSince1970 / dayScale
    let due      = dueDate.timeIntervalSince1970      / dayScale
    let done     = completionDate.timeIntervalSince1970 / dayScale

    // Guard: if submitted before release or due == assigned, skip
    guard due > assigned, done >= assigned else { return }

    // Tuneable constants — adjust S and a to taste
    let S: Double = 10.0
    let a: Double = 1.0
    updateKarma(assignedDate: assigned, dueDate: due, daysTakenForCompletion: done, S: S, a: a)
}

// MARK: - Keys / Unlock

func unlockApp(numLockedApps: Int, usagePercentage: Double) {
    let cost = pow(Double(numLockedApps), 1.5) + 0.5 * pow(usagePercentage, 1.25) + 10.0

    @AppStorage("keys", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var keys: Double = 0.0
    keys -= cost
}

// MARK: - Z-Score

func getZScoreFromKarma() -> Double {
    @AppStorage("karma", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var karma: Double = 0.0
    // Karma 100 → z = 3, Karma 50 → z = 0, Karma 0 → z = -3
    return -0.06 * karma + 3
}

// MARK: - App Locking

func lockAppByKarma() -> String {
    @AppStorage("appCounts", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var appCounts: [String: Int] = [:]

    guard !appCounts.isEmpty else { return "" }

    let sortedApps = appCounts.sorted { $0.value < $1.value }
    let totalFrequency = sortedApps.reduce(0) { $0 + $1.value }

    let precision: Float = 1000.0
    let meanZScore = Float(getZScoreFromKarma())

    let distribution = GKGaussianDistribution(
        randomSource: GKARC4RandomSource(),
        mean: meanZScore * precision,
        deviation: 1.0 * precision
    )

    let zRand = Double(distribution.nextInt()) / Double(precision)
    var normalizedPosition = (zRand + 3.0) / 6.0
    normalizedPosition = max(0.0, min(1.0, normalizedPosition))

    let targetCumulativeFrequency = normalizedPosition * Double(totalFrequency)

    var currentCumulative = 0.0
    var appToLock = sortedApps.last!.key

    for app in sortedApps {
        currentCumulative += Double(app.value)
        if currentCumulative >= targetCumulativeFrequency {
            appToLock = app.key
            break
        }
    }

    return appToLock
}

/// Locks the appropriate number of apps based on current karma.
/// Formula: (6 - karma/20) * 100  gives a percentage; we apply that fraction to total app count.
/// Returns the list of bundle IDs that were (would be) locked.
@discardableResult
func performSundayLocking() -> [String] {
    @AppStorage("karma", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var karma: Double = 0.0

    @AppStorage("appCounts", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var appCounts: [String: Int] = [:]

    @AppStorage("lockedApps", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var lockedApps: [String] = []

    let totalApps = appCounts.count
    guard totalApps > 0 else { return [] }

    // Percentage of apps to lock, clamped to [0, 100]
    let lockPercent = max(0, min(100, (6.0 - karma / 20.0) * 100.0))
    let numToLock   = Int((lockPercent / 100.0 * Double(totalApps)).rounded(.up))

    var locked: [String] = []
    // Avoid duplicate locks in one pass by temporarily removing each picked app
    var snapshot = appCounts
    for _ in 0 ..< numToLock {
        let picked = lockAppByKarma()
        if !picked.isEmpty && !locked.contains(picked) {
            locked.append(picked)
            availableApps.removeValue(forKey: picked)
        }
    }

    lockedApps = locked
    return locked
}

// MARK: - Sunday Scheduler

final class LockScheduler: ObservableObject {
    private let defaults = UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked")
    private var timer: Timer?

    private var lastLockKey: String { "lastWeeklyLockDate" }

    func start() {
        checkAndLockIfNeeded()

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkAndLockIfNeeded()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkAndLockIfNeeded() {
        let now = Date()
        let calendar = Calendar.current
        
        // Scheduler fix kept: Ensures if they miss exactly 12:01 AM, it still fires.
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return }

        let currentWeekString = ISO8601DateFormatter().string(from: startOfWeek)
        
        if defaults?.string(forKey: lastLockKey) != currentWeekString {
            defaults?.set(currentWeekString, forKey: lastLockKey)
            let locked = performSundayLocking()
            print("Weekly lock: locked \(locked.count) app(s): \(locked)")
            
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    deinit { stop() }
}

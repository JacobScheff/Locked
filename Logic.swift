//
//  Logic.swift
//  Locked
//

import Foundation
import SwiftUI
import GameplayKit
import Combine

// MARK: - Shared Storage
final class LogicStore {
    static let shared = LogicStore()
    
    // Using @AppStorage inside the logic class directly uses your custom extension!
    // This perfectly prevents UserDefaults decoding failures and data wiping.
    
    @AppStorage("karma", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var karma: Double = 0.0
    
    @AppStorage("keys", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var keys: Double = 0.0
    
    @AppStorage("appCounts", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var appCounts: [String: Int] = [:]
    
    @AppStorage("lockedApps", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var lockedApps: [String] = []
    
    @AppStorage("lastOpenedApp", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var lastOpenedApp: String = ""
    
    @AppStorage("eventState", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var eventState: String = "Close"
    
    // Dates still rely on the standard defaults.object fallback
    private let defaults = UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked")!
    
    var lastOpened: Date {
        get { defaults.object(forKey: "lastOpened") as? Date ?? Date() }
        set { defaults.set(newValue, forKey: "lastOpened") }
    }
    
    private init() {}
}

// MARK: - Karma

// MARK: - Karma

func calculateKarmaDelta(releaseDate: Date, dueDate: Date, completionDate: Date) -> Double {
    let dayScale: Double = 86_400          // seconds per day
    let assigned = releaseDate.timeIntervalSince1970 / dayScale
    let due      = dueDate.timeIntervalSince1970      / dayScale
    let done     = completionDate.timeIntervalSince1970 / dayScale

    guard due > assigned else { return 0.0 }

    // Calculate how much time they had total, and how early they submitted
    let totalDuration = due - assigned
    let timeEarly = due - done
    
    // Ex: +100 Karma for completing instantly, 0 for exactly on time, negative if late.
    let maxKarmaBonus = 100.0
    return (timeEarly / totalDuration) * maxKarmaBonus
}

// MARK: - Keys / Unlock

func unlockApp(numLockedApps: Int, usagePercentage: Double) {
    let cost = pow(Double(numLockedApps), 1.5) + 0.5 * pow(usagePercentage, 1.25) + 10.0

    LogicStore.shared.keys -= cost
}

// MARK: - Z-Score

func getZScoreFromKarma() -> Double {
    let karma = LogicStore.shared.karma
    // Karma 100 → z = -3, Karma 50 → z = 0, Karma 0 → z = 3
    return -0.06 * karma + 3
}

// MARK: - App Locking

func lockAppByKarma(from snapshot: [String: Int]) -> String {
    guard !snapshot.isEmpty else { return "" }

    let sortedApps = snapshot.sorted { $0.value < $1.value }
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
/// Returns the list of bundle IDs/names that were (would be) locked.
@discardableResult
func performSundayLocking() -> [String] {
    let store = LogicStore.shared
    let karma = store.karma
    
    // Copy app counts to a working snapshot
    var snapshot = store.appCounts
    
    // Prevent the app itself ("Locked") from ever being locked
    snapshot.removeValue(forKey: "Locked")
    
    let totalApps = snapshot.count
    guard totalApps > 0 else { return [] }

    // Corrected lock formula:
    // 100 Karma = 0% locked. 77 Karma = 23% locked. 0 Karma = 100% locked.
    let lockPercent = max(0.0, min(100.0, 100.0 - karma))
    
    // Calculate raw number of apps to lock, rounding up to ensure at least 1 app locks if lockPercent > 0
    let numToLock = Int((lockPercent / 100.0 * Double(totalApps)).rounded(.up))

    var locked: [String] = []
    
    for _ in 0 ..< numToLock {
        // Pass the updated snapshot to ensure we don't pick the same app twice
        let picked = lockAppByKarma(from: snapshot)
        if !picked.isEmpty && !locked.contains(picked) {
            locked.append(picked)
            snapshot.removeValue(forKey: picked) // Remove so it isn't picked again
        }
    }

    store.lockedApps = locked
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

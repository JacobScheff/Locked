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
    
    @AppStorage("emergencyOverrideUntil", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var emergencyOverrideUntil: Double = 0
    
    @AppStorage("innerVaultUnlockedUntil", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var innerVaultUnlockedUntil: Double = 0
    
    // Dates still rely on the standard defaults.object fallback
    private let defaults = UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked")!
    
    var isEmergencyOverrideActive: Bool {
        Date(timeIntervalSince1970: defaults.double(forKey: EmergencyOverride.untilKey)) > Date()
    }
    
    func activateEmergencyOverride() {
        let expiry = Date().addingTimeInterval(EmergencyOverride.duration).timeIntervalSince1970
        defaults.set(expiry, forKey: EmergencyOverride.untilKey)
        emergencyOverrideUntil = expiry
        lockInnerVault()
        ScreenTimeShields.clear()
        ScreenTimeMonitor.startEmergencyOverrideWindow(until: Date(timeIntervalSince1970: expiry))
    }
    
    func endEmergencyOverride() {
        defaults.set(0.0, forKey: EmergencyOverride.untilKey)
        emergencyOverrideUntil = 0
        lockInnerVault()
        ScreenTimeMonitor.stopEmergencyOverrideWindow()
        ScreenTimeShields.sync()
    }
    
    func unlockInnerVault() {
        let until = defaults.double(forKey: EmergencyOverride.untilKey)
        defaults.set(until, forKey: InnerVault.unlockedUntilKey)
        innerVaultUnlockedUntil = until
    }
    
    func lockInnerVault() {
        defaults.set(0.0, forKey: InnerVault.unlockedUntilKey)
        innerVaultUnlockedUntil = 0
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
    let karma = AppGroupStore.defaults.double(forKey: "karma")
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
        deviation: precision
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
/// Returns the list of names that were locked. Safety-critical apps are never included.
@discardableResult
func performSundayLocking() -> [String] {
    let store = LogicStore.shared
    let karma = AppGroupStore.defaults.double(forKey: "karma")
    
    var snapshot = ExcludedApps.strippingExcluded(UsageStore.loadAppCounts())
    
    let totalApps = snapshot.count
    guard totalApps > 0 else { return [] }

    // 100 Karma = 0% locked. 77 Karma = 23% locked. 0 Karma = 100% locked.
    let lockPercent = max(0.0, min(100.0, 100.0 - karma))
    let numToLock = Int((lockPercent / 100.0 * Double(totalApps)).rounded(.up))

    var locked: [String] = []
    
    for _ in 0 ..< numToLock {
        let picked = lockAppByKarma(from: snapshot)
        if !picked.isEmpty && !locked.contains(picked) && !ExcludedApps.isExcludedName(picked) {
            locked.append(picked)
            snapshot.removeValue(forKey: picked)
        }
    }

    UsageStore.saveLockedApps(locked)
    store.lockedApps = locked
    ScreenTimeShields.sync()
    return locked
}

func checkAndPerformWeeklyLockIfNeeded() {
    let defaults = AppGroupStore.defaults
    let now = Date()
    let calendar = Calendar.current
    guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return }

    let currentWeekString = ISO8601DateFormatter().string(from: startOfWeek)
    let lastLockKey = "lastWeeklyLockDate"
    if defaults.string(forKey: lastLockKey) != currentWeekString {
        defaults.set(currentWeekString, forKey: lastLockKey)
        let locked = performSundayLocking()
        print("Weekly lock: locked \(locked.count) app(s): \(locked)")
    }
}

// MARK: - Sunday Scheduler

final class LockScheduler: ObservableObject {
    private var timer: Timer?

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
        checkAndPerformWeeklyLockIfNeeded()
        ScreenTimeShields.sync()
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    deinit { stop() }
}

// MARK: - Inner vault

enum InnerVault {
    static let unlockedUntilKey = "innerVaultUnlockedUntil"
    static let holdDuration: TimeInterval = 2.4
    static let boltCount = 4

    static func isUnlocked(
        at date: Date = .now,
        defaults: UserDefaults = AppGroupStore.defaults
    ) -> Bool {
        guard EmergencyOverride.isActive(at: date, defaults: defaults) else { return false }
        let unlockedUntil = defaults.double(forKey: unlockedUntilKey)
        let overrideUntil = defaults.double(forKey: EmergencyOverride.untilKey)
        return unlockedUntil > 0 && abs(unlockedUntil - overrideUntil) < 0.5
    }
}

func clampKeys(_ value: Double) -> Double {
    max(0, value)
}

func clampKarma(_ value: Double) -> Double {
    min(100, max(0, value))
}

func adjustedKeys(from current: Double, by delta: Int) -> Double {
    let base = Int(clampKeys(current).rounded(.towardZero))
    return Double(max(0, base + delta))
}

func adjustedKarma(from current: Double, by delta: Int) -> Double {
    let base = Int(clampKarma(current).rounded(.towardZero))
    return Double(min(100, max(0, base + delta)))
}

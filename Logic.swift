//
//  Logic.swift
//  Locked
//

import Foundation
import SwiftUI
import GameplayKit
import Combine
#if !targetEnvironment(macCatalyst)
import FamilyControls
import ManagedSettings
#endif

// MARK: - Shared Storage
final class LogicStore {
    static let shared = LogicStore()
    
    // Using @AppStorage inside the logic class directly uses your custom extension!
    // This perfectly prevents UserDefaults decoding failures and data wiping.
    
    @AppStorage("karma", store: AppGroupStore.defaults)
    var karma: Double = 100.0
    
    @AppStorage("keys", store: AppGroupStore.defaults)
    var keys: Double = 0.0
    
    @AppStorage("appCounts", store: AppGroupStore.defaults)
    var appCounts: [String: Int] = [:]
    
    @AppStorage("lockedApps", store: AppGroupStore.defaults)
    var lockedApps: [String] = []
    
    @AppStorage("emergencyOverrideUntil", store: AppGroupStore.defaults)
    var emergencyOverrideUntil: Double = 0
    
    @AppStorage("innerVaultUnlockedUntil", store: AppGroupStore.defaults)
    var innerVaultUnlockedUntil: Double = 0
    
    private let defaults = AppGroupStore.defaults
    
    var isEmergencyOverrideActive: Bool {
        EmergencyOverride.isActive()
    }
    
    func activateEmergencyOverride() {
        let expiry = Date().addingTimeInterval(EmergencyOverride.duration).timeIntervalSince1970
        EmergencyOverride.setUntil(expiry)
        emergencyOverrideUntil = expiry
        lockInnerVault()
        ScreenTimeShields.clear()
        ScreenTimeMonitor.startEmergencyOverrideWindow(until: Date(timeIntervalSince1970: expiry))
    }
    
    func endEmergencyOverride() {
        EmergencyOverride.setUntil(0)
        emergencyOverrideUntil = 0
        lockInnerVault()
        ScreenTimeMonitor.stopEmergencyOverrideWindow()
        ScreenTimeShields.sync()
    }
    
    func unlockInnerVault() {
        let until = EmergencyOverride.untilTimestamp()
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
    let raw = pow(Double(numLockedApps), 1.5) + 0.5 * pow(usagePercentage, 1.25) + 10.0
    _ = Economy.spendKeys(Double(max(1, Int(raw.rounded()))))
}

// MARK: - Z-Score

func getZScoreFromKarma() -> Double {
    let karma = Economy.karma()
    // Karma 100 → z = -3, Karma 50 → z = 0, Karma 0 → z = 3
    return -0.06 * karma + 3
}

// MARK: - App Locking

func lockAppByKarma<Key: Hashable>(from snapshot: [Key: Int]) -> Key? {
    guard !snapshot.isEmpty else { return nil }

    let sortedApps = snapshot.sorted { $0.value < $1.value }
    let totalFrequency = max(1, sortedApps.reduce(0) { $0 + $1.value })

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

/// Every app karma may lock this week, keyed by its Screen Time token and
/// weighted by usage. Picker tokens are the primary pool because the main
/// app always has them; report tokens fill in apps that only came from a
/// category pick. An app with no recorded usage keeps weight 1 so it is
/// still eligible without outweighing anything that was actually used.
func weeklyLockCandidates(
    selection: FamilyActivitySelection,
    appCounts: [String: Int],
    tokenMap: [String: ApplicationToken]
) -> [ApplicationToken: Int] {
    var pool: [ApplicationToken: Int] = [:]
    for token in selection.applicationTokens {
        pool[token] = 1
    }
    for (name, token) in tokenMap where !ExcludedApps.isExcludedName(name) {
        if pool[token] != nil || selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty {
            pool[token] = max(1, appCounts[name] ?? 0)
        }
    }
    for token in ExcludedApps.tokens {
        pool.removeValue(forKey: token)
    }
    return pool
}

/// How many of `totalApps` karma locks. 100 karma = 0%, 77 karma = 23%, 0 karma = 100%.
func weeklyLockCount(karma: Double, totalApps: Int, minimumLockCount: Int = 0) -> Int {
    guard totalApps > 0 else { return 0 }
    let lockPercent = max(0.0, min(100.0, 100.0 - karma))
    let byKarma = Int((lockPercent / 100.0 * Double(totalApps)).rounded(.up))
    return min(totalApps, max(byKarma, min(minimumLockCount, totalApps)))
}

/// Locks the appropriate number of apps based on current karma.
///
/// Tokens are the only thing that gets locked. An app is never marked locked
/// by name without a token to shield, and the name list is derived from the
/// shielded tokens, so the UI and SpringBoard can't disagree.
/// Returns the display names that were locked (unnamed tokens are still shielded).
@discardableResult
func performSundayLocking(
    using selection: FamilyActivitySelection? = nil,
    minimumLockCount: Int = 0
) -> [String] {
    let store = LogicStore.shared
    let karma = Economy.karma()
    let picker = ActivitySelectionStore.expandingCategories(selection ?? ActivitySelectionStore.load())

    var pool = weeklyLockCandidates(
        selection: picker,
        appCounts: UsageStore.loadAppCounts(),
        tokenMap: UsageStore.loadTokenMap()
    )
    guard !pool.isEmpty else { return [] }

    let numToLock = weeklyLockCount(karma: karma, totalApps: pool.count, minimumLockCount: minimumLockCount)

    var lockedTokens: Set<ApplicationToken> = []
    while lockedTokens.count < numToLock, let picked = lockAppByKarma(from: pool) {
        pool.removeValue(forKey: picked)
        lockedTokens.insert(picked)
    }

    ScreenTimeShields.lock(tokens: lockedTokens)
    let names = UsageStore.loadLockedApps()
    store.lockedApps = names
    return names
}

let weeklyLockDateKey = "lastWeeklyLockDate"

func currentWeekStamp(for date: Date = Date()) -> String? {
    guard let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: date)?.start else { return nil }
    return ISO8601DateFormatter().string(from: startOfWeek)
}

/// Runs the weekly lock once per week, and only once a pool of apps exists.
/// The stamp is written after a successful pick so a run that had nothing to
/// choose from is retried later; a week that already locked is never re-run,
/// because that would re-lock apps the user paid Keys to unlock.
func checkAndPerformWeeklyLockIfNeeded() {
    guard let currentWeekString = currentWeekStamp() else { return }
    let alreadyRan = AppGroupStore.sharedString(forKey: weeklyLockDateKey) == currentWeekString
        || AppGroupStore.defaults.string(forKey: weeklyLockDateKey) == currentWeekString
    guard !alreadyRan else { return }

    let pool = weeklyLockCandidates(
        selection: ActivitySelectionStore.load(),
        appCounts: UsageStore.loadAppCounts(),
        tokenMap: UsageStore.loadTokenMap()
    )
    guard !pool.isEmpty else { return }

    AppGroupStore.setSharedString(currentWeekString, forKey: weeklyLockDateKey)
    let locked = performSundayLocking()
    print("Weekly lock: locked \(locked.count) named app(s): \(locked); \(LockedTokenStore.load().count) token(s) shielded")
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
    static let tickCount = 40
    static let degreesPerTick = 360.0 / Double(tickCount)
    static let combinationLength = 3
    static let resetWrongWay = 55.0

    static func randomCombination() -> [Int] {
        var numbers: [Int] = []
        while numbers.count < combinationLength {
            let candidate = Int.random(in: 0..<tickCount)
            let tooClose = numbers.contains { number in
                let gap = abs(number - candidate)
                return min(gap, tickCount - gap) < 5
            }
            if !tooClose {
                numbers.append(candidate)
            }
        }
        return numbers
    }

    static func minimumTravel(for step: Int) -> Double {
        step == 0 ? 330 : 160
    }

    static func number(at dialAngle: Double) -> Int {
        // The face paints number N at +N ticks. A positive (clockwise) dial
        // rotation therefore brings a lower number under the top pointer.
        let ticks = (-dialAngle / degreesPerTick).rounded()
        var number = Int(ticks) % tickCount
        if number < 0 { number += tickCount }
        return number
    }

    static func isUnlocked(
        at date: Date = .now,
        defaults: UserDefaults = AppGroupStore.defaults
    ) -> Bool {
        guard EmergencyOverride.isActive(at: date, defaults: defaults) else { return false }
        let unlockedUntil = defaults.double(forKey: unlockedUntilKey)
        let overrideUntil = EmergencyOverride.untilTimestamp(defaults: defaults)
        return unlockedUntil > 0 && abs(unlockedUntil - overrideUntil) < 0.5
    }
}

func adjustedKeys(from current: Double, by delta: Int) -> Double {
    let base = Int(clampKeys(current).rounded(.towardZero))
    return Double(max(0, base + delta))
}

func adjustedKarma(from current: Double, by delta: Int) -> Double {
    let base = Int(clampKarma(current).rounded(.towardZero))
    return Double(min(100, max(0, base + delta)))
}

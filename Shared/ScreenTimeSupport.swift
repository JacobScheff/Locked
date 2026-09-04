//
//  ScreenTimeSupport.swift
//  Locked
//
//  Shared Screen Time helpers used by the app and its extensions.
//

import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

enum AppGroupStore {
    static let suiteName = "group.com.Jacob-Scheff.Locked"
    static let usageDidUpdateName = "com.Jacob-Scheff.Locked.usageDidUpdate"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func encodeJSON<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    static func decodeJSON<T: Decodable>(_ type: T.Type, from raw: String?) -> T? {
        guard let raw, let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

/// Apps that must never be tracked, shown, or shielded.
/// Phone / Messages / FaceTime / Find My / Wallet / Clock stay available for safety.
enum ExcludedApps {
    static let bundleIdentifiers: Set<String> = [
        "com.Jacob-Scheff.Locked",
        "com.Jacob-Scheff.Locked.Locked-Widget",
        "com.Jacob-Scheff.Locked.DeviceActivityMonitor",
        "com.Jacob-Scheff.Locked.DeviceActivityReport",
        "com.Jacob-Scheff.Locked.ShieldConfiguration",
        "com.apple.Preferences",
        "com.apple.PreferencesUI",
        "com.apple.mobilephone",
        "com.apple.InCallService",
        "com.apple.MobilePhone",
        "com.apple.MobileSMS",
        "com.apple.facetime",
        "com.apple.FaceTime",
        "com.apple.findmy",
        "com.apple.FindMy",
        "com.apple.Passbook",
        "com.apple.PassbookUIService",
        "com.apple.mobiletimer",
        "com.apple.EmergencySOS"
    ]

    static let displayNames: Set<String> = [
        "Locked",
        "Settings",
        "Phone",
        "Messages",
        "FaceTime",
        "Find My",
        "Wallet",
        "Clock",
        "Emergency SOS"
    ]

    static func isExcluded(bundleIdentifier: String?, displayName: String?) -> Bool {
        if let bundleIdentifier {
            if bundleIdentifiers.contains(bundleIdentifier) { return true }
            if bundleIdentifier.hasPrefix("com.Jacob-Scheff.Locked") { return true }
        }
        if let displayName, displayNames.contains(displayName) { return true }
        return false
    }

    static func isExcludedName(_ name: String) -> Bool {
        isExcluded(bundleIdentifier: nil, displayName: name)
    }

    static var tokens: Set<ApplicationToken> {
        Set(bundleIdentifiers.compactMap { Application(bundleIdentifier: $0).token })
    }

    static func strippingExcluded(_ counts: [String: Int]) -> [String: Int] {
        counts.filter { !isExcludedName($0.key) }
    }

    static func strippingExcluded(_ names: [String]) -> [String] {
        names.filter { !isExcludedName($0) }
    }
}

extension ManagedSettingsStore.Name {
    static let locked = Self("Locked")
}

extension DeviceActivityName {
    static let daily = Self("locked.daily")
    static let emergencyOverride = Self("locked.emergencyOverride")
}

extension DeviceActivity.DeviceActivityReport.Context {
    static let usage = Self("LockedUsage")
}

enum ActivitySelectionStore {
    static let key = "familyActivitySelection"

    static func load() -> FamilyActivitySelection {
        guard let data = AppGroupStore.defaults.data(forKey: key),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }
        return selection
    }

    static func save(_ selection: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(selection) {
            AppGroupStore.defaults.set(data, forKey: key)
        }
    }

    static var hasSelection: Bool {
        let selection = load()
        return !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    }

    static var lockableApplicationTokens: Set<ApplicationToken> {
        load().applicationTokens.subtracting(ExcludedApps.tokens)
    }
}

enum UsageStore {
    static func loadAppCounts() -> [String: Int] {
        let raw = AppGroupStore.defaults.string(forKey: "appCounts")
        let decoded = AppGroupStore.decodeJSON([String: Int].self, from: raw) ?? [:]
        return ExcludedApps.strippingExcluded(decoded)
    }

    static func loadLockedApps() -> [String] {
        let raw = AppGroupStore.defaults.string(forKey: "lockedApps")
        let decoded = AppGroupStore.decodeJSON([String].self, from: raw) ?? []
        return ExcludedApps.strippingExcluded(decoded)
    }

    static func loadScreenTime() -> Int {
        AppGroupStore.defaults.integer(forKey: "screentime")
    }

    static func loadTokens() -> [String: Data] {
        AppGroupStore.decodeJSON([String: Data].self, from: AppGroupStore.defaults.string(forKey: "appTokens")) ?? [:]
    }

    static func token(for name: String) -> ApplicationToken? {
        guard let data = loadTokens()[name] else { return nil }
        return try? JSONDecoder().decode(ApplicationToken.self, from: data)
    }

    static func saveUsage(appCounts: [String: Int], tokens: [String: Data], totalSeconds: Int) {
        let filteredCounts = ExcludedApps.strippingExcluded(appCounts)
        let filteredTokens = tokens.filter { !ExcludedApps.isExcludedName($0.key) }
        if let raw = AppGroupStore.encodeJSON(filteredCounts) {
            AppGroupStore.defaults.set(raw, forKey: "appCounts")
        }
        if let raw = AppGroupStore.encodeJSON(filteredTokens) {
            AppGroupStore.defaults.set(raw, forKey: "appTokens")
        }
        AppGroupStore.defaults.set(totalSeconds > 0 ? totalSeconds : filteredCounts.values.reduce(0, +), forKey: "screentime")
        pingMainApp()
    }

    static func saveLockedApps(_ locked: [String]) {
        let filtered = ExcludedApps.strippingExcluded(locked)
        if let raw = AppGroupStore.encodeJSON(filtered) {
            AppGroupStore.defaults.set(raw, forKey: "lockedApps")
        }
    }

    static func pingMainApp() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(AppGroupStore.usageDidUpdateName as CFString),
            nil,
            nil,
            true
        )
    }
}

enum ScreenTimeShields {
    static var store: ManagedSettingsStore {
        ManagedSettingsStore(named: .locked)
    }

    /// Applies or clears shields from the current lock list and emergency-override state.
    static func sync() {
        if EmergencyOverride.isActive() {
            clear()
            return
        }

        let lockedNames = UsageStore.loadLockedApps()
        var tokens = Set(lockedNames.compactMap { UsageStore.token(for: $0) })
        tokens.subtract(ExcludedApps.tokens)
        store.shield.applications = tokens.isEmpty ? nil : tokens
    }

    static func clear() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }
}

enum ScreenTimeMonitor {
    static func startDaily() {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        do {
            try DeviceActivityCenter().startMonitoring(.daily, during: schedule)
        } catch {
            print("Failed to start daily Screen Time monitoring: \(error)")
        }
    }

    static func startEmergencyOverrideWindow(until expiry: Date) {
        let calendar = Calendar.current
        let start = calendar.dateComponents([.hour, .minute, .second], from: Date())
        let end = calendar.dateComponents([.hour, .minute, .second], from: expiry)
        let schedule = DeviceActivitySchedule(
            intervalStart: start,
            intervalEnd: end,
            repeats: false
        )
        do {
            try DeviceActivityCenter().startMonitoring(.emergencyOverride, during: schedule)
        } catch {
            print("Failed to start emergency override schedule: \(error)")
        }
    }

    static func stopEmergencyOverrideWindow() {
        DeviceActivityCenter().stopMonitoring([.emergencyOverride])
    }
}

enum EmergencyOverride {
    static let suiteName = AppGroupStore.suiteName
    static let untilKey = "emergencyOverrideUntil"
    static let duration: TimeInterval = 60 * 60
    static let strikesToBreak = 3

    static func isActive(at date: Date = .now, defaults: UserDefaults? = UserDefaults(suiteName: suiteName)) -> Bool {
        remaining(at: date, defaults: defaults) > 0
    }

    static func remaining(at date: Date = .now, defaults: UserDefaults? = UserDefaults(suiteName: suiteName)) -> TimeInterval {
        let until = defaults?.double(forKey: untilKey) ?? 0
        return max(0, Date(timeIntervalSince1970: until).timeIntervalSince(date))
    }

    static func formatRemaining(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

func usageFilter(for selection: FamilyActivitySelection, days: Int = 7) -> DeviceActivityFilter {
    let now = Date()
    let start = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
    let interval = DateInterval(start: start, end: now)
    let applications = selection.applicationTokens.subtracting(ExcludedApps.tokens)

    if applications.isEmpty && selection.categoryTokens.isEmpty {
        return DeviceActivityFilter(
            segment: .daily(during: interval),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
    }

    return DeviceActivityFilter(
        segment: .daily(during: interval),
        users: .all,
        devices: .init([.iPhone, .iPad]),
        applications: applications,
        categories: selection.categoryTokens
    )
}

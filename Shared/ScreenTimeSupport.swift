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

extension Array: @retroactive RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

extension Dictionary: @retroactive RawRepresentable where Key == String, Value: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Key: Value].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return result
    }
}

enum AppGroupStore {
    static let suiteName = "group.com.Jacob-Scheff.Locked"
    static let usageDidUpdateName = "com.Jacob-Scheff.Locked.usageDidUpdate"

    /// One suite instance. Repeated `UserDefaults(suiteName:)` lookups from
    /// Device Activity extensions trigger CFPrefs `kCFPreferencesAnyUser`
    /// failures and detach from cfprefsd.
    static let defaults: UserDefaults = {
        prepareContainer()
        return UserDefaults(suiteName: suiteName) ?? .standard
    }()

    /// Create the group container before any suite read. Doing this after
    /// a `UserDefaults(suiteName:)` lookup is what triggers the
    /// `kCFPreferencesAnyUser` / cfprefsd detach on first launch.
    static func prepareContainer() {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName) else {
            return
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
    }

    static func fileURL(for key: String) -> URL? {
        containerURL?.appendingPathComponent(key, isDirectory: false)
    }

    /// Device Activity extensions often cannot read the app-group suite
    /// through cfprefsd. Files in the group container still work.
    static func setSharedData(_ data: Data, forKey key: String) {
        defaults.set(data, forKey: key)
        if let url = fileURL(for: key) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func sharedData(forKey key: String) -> Data? {
        if let url = fileURL(for: key),
           let data = try? Data(contentsOf: url),
           !data.isEmpty {
            return data
        }
        return defaults.data(forKey: key)
    }

    static func setSharedString(_ string: String, forKey key: String) {
        defaults.set(string, forKey: key)
        if let url = fileURL(for: key), let data = string.data(using: .utf8) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func sharedString(forKey key: String) -> String? {
        if let data = sharedData(forKey: key),
           let string = String(data: data, encoding: .utf8),
           !string.isEmpty {
            return string
        }
        return defaults.string(forKey: key)
    }

    static func encodeJSON<T: Encodable>(_ value: T) -> String? {
        // TokenCoding prefers binary plists, which cannot become a UTF-8 string.
        // JSON is required here so name→token maps actually persist.
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    static func decodeJSON<T: Decodable>(_ type: T.Type, from raw: String?) -> T? {
        guard let raw, let data = raw.data(using: .utf8) else { return nil }
        return TokenCoding.decode(type, from: data)
    }
}

extension UserDefaults {
    static var lockedGroup: UserDefaults { AppGroupStore.defaults }
}

enum TokenCoding {
    static func encode<T: Encodable>(_ value: T) -> Data? {
        if let data = try? PropertyListEncoder().encode(value) { return data }
        return try? JSONEncoder().encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        if let value = try? PropertyListDecoder().decode(type, from: data) { return value }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func id<T: Encodable>(for value: T) -> String {
        encode(value)?.base64EncodedString() ?? UUID().uuidString
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

    static func isBlankName(_ name: String) -> Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static var tokens: Set<ApplicationToken> {
        Set(bundleIdentifiers.compactMap { Application(bundleIdentifier: $0).token })
    }

    static func strippingExcluded(_ counts: [String: Int]) -> [String: Int] {
        counts.filter { !isExcludedName($0.key) && !isBlankName($0.key) && $0.value > 0 }
    }

    static func strippingExcluded(_ names: [String]) -> [String] {
        names.filter { !isExcludedName($0) && !isBlankName($0) }
    }
}

enum InstalledApps {
    /// Screen Time still reports deleted apps historically. A current
    /// display name, and a live token when we have a bundle ID, mean the app is still on the device.
    static func isPresent(bundleIdentifier: String?, displayName: String?) -> Bool {
        // Application(bundleIdentifier:).token is nil in the main app, so a missing
        // token cannot be used as proof that the app was deleted.
        guard let displayName, !ExcludedApps.isBlankName(displayName) else { return false }
        return true
    }
}

extension ManagedSettingsStore.Name {
    static let locked = Self("Locked")
}

extension DeviceActivityName {
    static let daily = Self("locked.daily")
    static let emergencyOverride = Self("locked.emergencyOverride")
}

enum LockedReportContext {
    static let name = "LockedUsage"
}

enum ActivitySelectionStore {
    static let key = "familyActivitySelection"

    /// Category picks must expand to individual `ApplicationToken`s so we can
    /// lock one app without shielding every app in Social, Games, etc.
    static func expandingCategories(_ selection: FamilyActivitySelection) -> FamilyActivitySelection {
        guard !selection.includeEntireCategory else { return selection }
        var expanded = FamilyActivitySelection(includeEntireCategory: true)
        expanded.applicationTokens = selection.applicationTokens
        expanded.categoryTokens = selection.categoryTokens
        expanded.webDomainTokens = selection.webDomainTokens
        return expanded
    }

    static func load() -> FamilyActivitySelection {
        guard let data = AppGroupStore.sharedData(forKey: key),
              let selection = TokenCoding.decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection(includeEntireCategory: true)
        }
        return expandingCategories(selection)
    }

    static func save(_ selection: FamilyActivitySelection) {
        let expanded = expandingCategories(selection)
        if let data = TokenCoding.encode(expanded) {
            AppGroupStore.setSharedData(data, forKey: key)
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
        let raw = AppGroupStore.sharedString(forKey: "appCounts")
        let decoded = AppGroupStore.decodeJSON([String: Int].self, from: raw) ?? [:]
        return ExcludedApps.strippingExcluded(decoded)
    }

    static func loadLockedApps() -> [String] {
        let raw = AppGroupStore.sharedString(forKey: "lockedApps")
        let decoded = AppGroupStore.decodeJSON([String].self, from: raw) ?? []
        return ExcludedApps.strippingExcluded(decoded)
    }

    static func loadScreenTime() -> Int {
        AppGroupStore.defaults.integer(forKey: "screentime")
    }

    static var hasSnapshot: Bool {
        AppGroupStore.defaults.bool(forKey: "hasUsageSnapshot")
    }

    static let tokensKey = "appTokensData"
    static let tokensLegacyKey = "appTokens"

    static func loadTokens() -> [String: Data] {
        if let data = AppGroupStore.sharedData(forKey: tokensKey),
           let tokens = TokenCoding.decode([String: Data].self, from: data) {
            return tokens
        }
        return AppGroupStore.decodeJSON([String: Data].self, from: AppGroupStore.sharedString(forKey: tokensLegacyKey)) ?? [:]
    }

    static func saveTokens(_ tokens: [String: Data]) {
        if let data = TokenCoding.encode(tokens) {
            AppGroupStore.setSharedData(data, forKey: tokensKey)
        }
        if let raw = AppGroupStore.encodeJSON(tokens) {
            AppGroupStore.setSharedString(raw, forKey: tokensLegacyKey)
        }
    }

    static func loadTokenMap() -> [String: ApplicationToken] {
        var map: [String: ApplicationToken] = [:]
        for (name, data) in loadTokens() {
            if let token = TokenCoding.decode(ApplicationToken.self, from: data) {
                map[name] = token
            }
        }
        return map
    }

    static func saveToken(_ token: ApplicationToken, for name: String) {
        guard !ExcludedApps.isBlankName(name), !ExcludedApps.isExcludedName(name) else { return }
        guard let data = TokenCoding.encode(token) else { return }
        var tokens = loadTokens()
        tokens[name] = data
        saveTokens(tokens)
    }

    static func token(for name: String) -> ApplicationToken? {
        if let token = loadTokenMap()[name] { return token }
        // Device Activity extensions can resolve a token from a bundle ID.
        // The main app cannot; this is a no-op there.
        if let bundleID = loadBundleIDs()[name],
           let token = Application(bundleIdentifier: bundleID).token {
            saveToken(token, for: name)
            return token
        }
        return nil
    }

    static func loadBundleIDs() -> [String: String] {
        AppGroupStore.decodeJSON([String: String].self, from: AppGroupStore.sharedString(forKey: "appBundleIDs")) ?? [:]
    }

    static func isStillInstalled(name: String, bundleIDs: [String: String]? = nil) -> Bool {
        // Do not consult Application(bundleIdentifier:).token here. That property is
        // unavailable in the main app and was treating every managed app as deleted,
        // which cleared lockedApps and removed the shields.
        _ = bundleIDs
        return !ExcludedApps.isBlankName(name) && !ExcludedApps.isExcludedName(name)
    }

    static func saveUsage(
        appCounts: [String: Int],
        tokens: [String: Data],
        bundleIDs: [String: String]
    ) {
        let filteredCounts = ExcludedApps.strippingExcluded(appCounts)
        let remainingNames = Set(filteredCounts.keys)
        var mergedTokens = loadTokens()
        for (name, data) in tokens {
            mergedTokens[name] = data
        }
        let lockedTokenSet = LockedTokenStore.load()
        var keepNames = remainingNames.union(Set(loadLockedApps()))
        for (name, data) in mergedTokens {
            if let token = TokenCoding.decode(ApplicationToken.self, from: data),
               lockedTokenSet.contains(token) {
                keepNames.insert(name)
            }
        }
        let filteredTokens = mergedTokens.filter {
            keepNames.contains($0.key) || remainingNames.contains($0.key)
        }
        let total = filteredCounts.values.reduce(0, +)

        var ids = loadBundleIDs()
        for (name, bundleID) in bundleIDs where remainingNames.contains(name) {
            ids[name] = bundleID
        }
        for name in ids.keys where !remainingNames.contains(name) && !isStillInstalled(name: name, bundleIDs: ids) {
            ids.removeValue(forKey: name)
        }

        if let raw = AppGroupStore.encodeJSON(filteredCounts) {
            AppGroupStore.setSharedString(raw, forKey: "appCounts")
        }
        saveTokens(filteredTokens)
        if let raw = AppGroupStore.encodeJSON(ids) {
            AppGroupStore.setSharedString(raw, forKey: "appBundleIDs")
        }
        AppGroupStore.defaults.set(total, forKey: "screentime")
        AppGroupStore.defaults.set(true, forKey: "hasUsageSnapshot")
        var locked = loadLockedApps().filter { remainingNames.contains($0) || isStillInstalled(name: $0, bundleIDs: ids) }
        let lockedTokens = LockedTokenStore.load()
        for (name, data) in filteredTokens {
            guard let token = TokenCoding.decode(ApplicationToken.self, from: data),
                  lockedTokens.contains(token),
                  !locked.contains(name)
            else { continue }
            locked.append(name)
        }
        saveLockedApps(locked)
        applyShields(for: locked, encodedTokens: filteredTokens)
        pingMainApp()
    }

    static func saveLockedApps(_ locked: [String]) {
        let filtered = ExcludedApps.strippingExcluded(locked)
        if let raw = AppGroupStore.encodeJSON(filtered) {
            AppGroupStore.setSharedString(raw, forKey: "lockedApps")
        }
    }

    /// Applies shields in the same process that just decoded the tokens.
    /// Device Activity extensions cannot reliably round-trip tokens through cfprefsd.
    static func applyShields(for lockedNames: [String], encodedTokens: [String: Data]) {
        var tokens = LockedTokenStore.load()
        for name in lockedNames {
            if let data = encodedTokens[name],
               let token = TokenCoding.decode(ApplicationToken.self, from: data) {
                tokens.insert(token)
            } else if let token = token(for: name) {
                tokens.insert(token)
            }
        }
        tokens.subtract(ExcludedApps.tokens)
        guard !tokens.isEmpty else { return }
        ScreenTimeShields.lock(tokens: tokens)
    }

    static func unlock(name: String) {
        saveLockedApps(loadLockedApps().filter { $0 != name })
        if let token = token(for: name) {
            LockedTokenStore.remove(token)
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

struct UnnamedLockedApp: Identifiable, Hashable {
    let id: String
    let token: ApplicationToken
}

enum LockedTokenStore {
    static let key = "lockedAppTokens"

    static func load() -> Set<ApplicationToken> {
        guard let data = AppGroupStore.sharedData(forKey: key) else { return [] }
        return TokenCoding.decode(Set<ApplicationToken>.self, from: data) ?? []
    }

    static func save(_ tokens: Set<ApplicationToken>) {
        let filtered = tokens.subtracting(ExcludedApps.tokens)
        if let data = TokenCoding.encode(filtered) {
            AppGroupStore.setSharedData(data, forKey: key)
        }
    }

    static func remove(_ token: ApplicationToken) {
        var tokens = load()
        tokens.remove(token)
        save(tokens)
    }

    static func remove(_ app: UnnamedLockedApp) {
        remove(app.token)
    }

    static func unnamedApps(excludingNames names: [String]) -> [UnnamedLockedApp] {
        let named = Set(names.compactMap { UsageStore.token(for: $0) })
        return load()
            .subtracting(named)
            .map { UnnamedLockedApp(id: TokenCoding.id(for: $0), token: $0) }
            .sorted { $0.id < $1.id }
    }
}

enum ScreenTimeShields {
    static let applicationLimit = 50

    /// A named store so these shields never merge with the default store
    /// or with restrictions written elsewhere in the app.
    static var store: ManagedSettingsStore {
        ManagedSettingsStore(named: .locked)
    }

    /// Shields only the given application tokens. Every other app stays open.
    static func lock(tokens: Set<ApplicationToken>) {
        let isolated = isolatedTokens(from: tokens)
        guard !isolated.isEmpty else { return }
        LockedTokenStore.save(isolated)
        apply(isolated)
    }

    /// Applies or clears shields from the current lock list and emergency-override state.
    static func sync(using selection: FamilyActivitySelection? = nil) {
        if EmergencyOverride.isActive() {
            clear()
            return
        }

        let picker = ActivitySelectionStore.expandingCategories(selection ?? ActivitySelectionStore.load())
        let lockedNames = UsageStore.loadLockedApps()
        let isolated = tokensToShield(
            lockedNames: lockedNames,
            selection: picker
        )
        if isolated.isEmpty {
            // Names without tokens are not a reason to wipe live shields.
            // Only clear when nothing is supposed to be locked.
            if lockedNames.isEmpty && LockedTokenStore.load().isEmpty {
                clear()
            }
            return
        }
        LockedTokenStore.save(isolated)
        apply(isolated)
    }

    /// Clears leftover settings, then shields only these application tokens.
    /// Categories and web domains are never applied — that would lock every
    /// app in a group instead of the specific apps karma picked.
    private static func apply(_ tokens: Set<ApplicationToken>) {
        let isolated = isolatedTokens(from: tokens)
        guard !isolated.isEmpty else { return }
        // Do not call clearAllSettings() here. That write is applied
        // asynchronously and can wipe the assignment that follows, which
        // leaves the UI saying "Locked" while SpringBoard has no shield.
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.applications = isolated
    }

    static func isolatedTokens(from tokens: Set<ApplicationToken>) -> Set<ApplicationToken> {
        let filtered = tokens.subtracting(ExcludedApps.tokens)
        guard filtered.count > applicationLimit else { return filtered }
        return Set(
            filtered
                .sorted { TokenCoding.id(for: $0) < TokenCoding.id(for: $1) }
                .prefix(applicationLimit)
        )
    }

    /// Isolates tokens for the current lock list only.
    /// Does not pad with arbitrary picker tokens and never uses category tokens.
    static func tokensToShield(
        lockedNames: [String],
        selection: FamilyActivitySelection
    ) -> Set<ApplicationToken> {
        _ = selection
        var tokens = LockedTokenStore.load()
        let named = UsageStore.loadTokenMap()
        for name in lockedNames {
            if let token = named[name] ?? UsageStore.token(for: name) {
                tokens.insert(token)
            }
        }
        for (name, token) in named where !lockedNames.contains(name) {
            tokens.remove(token)
        }
        return isolatedTokens(from: tokens)
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
        let center = DeviceActivityCenter()
        center.stopMonitoring([.daily])
        do {
            try center.startMonitoring(.daily, during: schedule)
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

    static func isActive(at date: Date = .now, defaults: UserDefaults? = AppGroupStore.defaults) -> Bool {
        remaining(at: date, defaults: defaults) > 0
    }

    static func remaining(at date: Date = .now, defaults: UserDefaults? = AppGroupStore.defaults) -> TimeInterval {
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
    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: Date())
    let start = calendar.date(byAdding: .day, value: -days, to: startOfToday) ?? startOfToday
    let end = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()
    let interval = DateInterval(start: start, end: end)
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

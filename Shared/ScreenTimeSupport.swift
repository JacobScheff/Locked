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

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func encodeJSON<T: Encodable>(_ value: T) -> String? {
        // JSON keeps [String: Data] token maps valid as UTF-8. PropertyList
        // binary (TokenCoding.encode) often fails String(encoding: .utf8),
        // which dropped appTokens and forced a category-wide shield fallback.
        if let data = try? JSONEncoder().encode(value),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        let plist = PropertyListEncoder()
        plist.outputFormat = .xml
        guard let data = try? plist.encode(value),
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    static func decodeJSON<T: Decodable>(_ type: T.Type, from raw: String?) -> T? {
        guard let raw, let data = raw.data(using: .utf8) else { return nil }
        if let value = try? JSONDecoder().decode(type, from: data) { return value }
        return TokenCoding.decode(type, from: data)
    }
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

enum PickerTokenStore {
    static let key = "pickerApplicationTokens"

    static func load() -> Set<ApplicationToken> {
        guard let data = AppGroupStore.defaults.data(forKey: key) else { return [] }
        return TokenCoding.decode(Set<ApplicationToken>.self, from: data) ?? []
    }

    static func save(_ tokens: Set<ApplicationToken>) {
        let filtered = tokens.subtracting(ExcludedApps.tokens)
        if let data = TokenCoding.encode(filtered) {
            AppGroupStore.defaults.set(data, forKey: key)
        }
    }
}

enum ActivitySelectionStore {
    static let key = "familyActivitySelection"

    /// PropertyList decode drops `includeEntireCategory`, so category picks
    /// lose their individual app tokens. Always rebuild with that flag on.
    static func normalized(_ stored: FamilyActivitySelection) -> FamilyActivitySelection {
        var selection = FamilyActivitySelection(includeEntireCategory: true)
        selection.applicationTokens = stored.applicationTokens
        selection.categoryTokens = stored.categoryTokens
        selection.webDomainTokens = stored.webDomainTokens
        if selection.applicationTokens.isEmpty {
            selection.applicationTokens = PickerTokenStore.load()
        }
        return selection
    }

    static func load() -> FamilyActivitySelection {
        guard let data = AppGroupStore.defaults.data(forKey: key),
              let stored = TokenCoding.decode(FamilyActivitySelection.self, from: data)
        else {
            var empty = FamilyActivitySelection(includeEntireCategory: true)
            empty.applicationTokens = PickerTokenStore.load()
            return empty
        }
        return normalized(stored)
    }

    static func save(_ selection: FamilyActivitySelection) {
        let normalized = normalized(selection)
        if let data = TokenCoding.encode(normalized) {
            AppGroupStore.defaults.set(data, forKey: key)
        }
        PickerTokenStore.save(normalized.applicationTokens)
        TokenIndex.persist(from: normalized)
    }

    static var hasSelection: Bool {
        let selection = load()
        return !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    }

    static var lockableApplicationTokens: Set<ApplicationToken> {
        let selection = load()
        var tokens = selection.applicationTokens
        tokens.formUnion(PickerTokenStore.load())
        tokens.formUnion(Set(TokenIndex.tokensByName(from: selection).values))
        return tokens.subtracting(ExcludedApps.tokens)
    }
}

/// Maps display names to the FamilyActivityPicker / usage-report tokens used
/// to shield one app at a time.
enum TokenIndex {
    static func tokensByName(from selection: FamilyActivitySelection? = nil) -> [String: ApplicationToken] {
        var result = UsageStore.tokensByName()
        let picker = selection ?? ActivitySelectionStore.load()
        for application in picker.applications {
            let name = application.localizedDisplayName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let name, !ExcludedApps.isBlankName(name), !ExcludedApps.isExcludedName(name),
                  let token = application.token
            else { continue }
            result[name] = token
        }
        return result
    }

    static func persist(from selection: FamilyActivitySelection) {
        UsageStore.saveTokens(tokensByName(from: selection))
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

    static var hasSnapshot: Bool {
        AppGroupStore.defaults.bool(forKey: "hasUsageSnapshot")
    }

    static func loadTokens() -> [String: Data] {
        AppGroupStore.decodeJSON([String: Data].self, from: AppGroupStore.defaults.string(forKey: "appTokens")) ?? [:]
    }

    static func token(for name: String) -> ApplicationToken? {
        guard let data = loadTokens()[name] else { return nil }
        return TokenCoding.decode(ApplicationToken.self, from: data)
    }

    static func tokensByName() -> [String: ApplicationToken] {
        var result: [String: ApplicationToken] = [:]
        for (name, data) in loadTokens() {
            if let token = TokenCoding.decode(ApplicationToken.self, from: data) {
                result[name] = token
            }
        }
        return result
    }

    static func saveTokens(_ tokensByName: [String: ApplicationToken]) {
        var existing = loadTokens()
        for (name, token) in tokensByName {
            guard !ExcludedApps.isBlankName(name),
                  !ExcludedApps.isExcludedName(name),
                  !name.hasPrefix("token:"),
                  let data = TokenCoding.encode(token)
            else { continue }
            existing[name] = data
        }
        if let raw = AppGroupStore.encodeJSON(existing) {
            AppGroupStore.defaults.set(raw, forKey: "appTokens")
        }
    }

    static func loadBundleIDs() -> [String: String] {
        AppGroupStore.decodeJSON([String: String].self, from: AppGroupStore.defaults.string(forKey: "appBundleIDs")) ?? [:]
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
        let total = filteredCounts.values.reduce(0, +)

        var ids = loadBundleIDs()
        for (name, bundleID) in bundleIDs where remainingNames.contains(name) {
            ids[name] = bundleID
        }
        for name in ids.keys where !remainingNames.contains(name) && !isStillInstalled(name: name, bundleIDs: ids) {
            ids.removeValue(forKey: name)
        }

        // Merge so a snapshot that omitted tokens cannot wipe the name → token
        // map used to shield and unlock individual apps.
        var mergedTokens = loadTokens()
        for (name, data) in tokens where remainingNames.contains(name) {
            mergedTokens[name] = data
        }
        for name in mergedTokens.keys where !remainingNames.contains(name) && !isStillInstalled(name: name, bundleIDs: ids) {
            mergedTokens.removeValue(forKey: name)
        }

        if let raw = AppGroupStore.encodeJSON(filteredCounts) {
            AppGroupStore.defaults.set(raw, forKey: "appCounts")
        }
        if let raw = AppGroupStore.encodeJSON(mergedTokens) {
            AppGroupStore.defaults.set(raw, forKey: "appTokens")
        }
        if let raw = AppGroupStore.encodeJSON(ids) {
            AppGroupStore.defaults.set(raw, forKey: "appBundleIDs")
        }
        AppGroupStore.defaults.set(total, forKey: "screentime")
        AppGroupStore.defaults.set(true, forKey: "hasUsageSnapshot")
        saveLockedApps(loadLockedApps().filter { remainingNames.contains($0) || isStillInstalled(name: $0, bundleIDs: ids) })
        pingMainApp()
    }

    static func saveLockedApps(_ locked: [String]) {
        let filtered = ExcludedApps.strippingExcluded(locked)
        if let raw = AppGroupStore.encodeJSON(filtered) {
            AppGroupStore.defaults.set(raw, forKey: "lockedApps")
        }
    }

    static func unlock(name: String) {
        saveLockedApps(loadLockedApps().filter { $0 != name })
        if let token = token(for: name) {
            LockedTokenStore.remove(token)
        }
    }

    static func name(for token: ApplicationToken) -> String? {
        tokensByName().first { $0.value == token }?.key
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
        guard let data = AppGroupStore.defaults.data(forKey: key) else { return [] }
        return TokenCoding.decode(Set<ApplicationToken>.self, from: data) ?? []
    }

    static func save(_ tokens: Set<ApplicationToken>) {
        let filtered = tokens.subtracting(ExcludedApps.tokens)
        if let data = TokenCoding.encode(filtered) {
            AppGroupStore.defaults.set(data, forKey: key)
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

/// Chooses which application tokens belong on the Screen Time shield.
/// Category-wide policies are never used: one locked app must not lock the home screen.
enum LockedShieldSet {
    static func applicationTokens(
        lockedNames: [String],
        storedTokens: Set<ApplicationToken>,
        tokenByName: [String: ApplicationToken]
    ) -> Set<ApplicationToken> {
        var tokens = Set<ApplicationToken>()
        let locked = Set(lockedNames)

        for name in locked {
            if let token = tokenByName[name] ?? tokenByName.first(where: {
                $0.key.caseInsensitiveCompare(name) == .orderedSame
            })?.value {
                tokens.insert(token)
            }
        }

        var nameByToken: [ApplicationToken: String] = [:]
        for (name, token) in tokenByName {
            nameByToken[token] = name
        }

        for token in storedTokens {
            if let name = nameByToken[token] {
                if locked.contains(name) {
                    tokens.insert(token)
                }
                continue
            }
            // Still locked, but Screen Time has not given us a display name yet.
            tokens.insert(token)
        }

        return tokens.subtracting(ExcludedApps.tokens)
    }
}

enum ScreenTimeShields {
    /// Named store so these shields do not collide with the default store.
    static var store: ManagedSettingsStore {
        ManagedSettingsStore(named: .locked)
    }

    /// Applies or clears shields from the current lock list and emergency-override state.
    /// Only `ApplicationToken`s are written — never category policies.
    static func sync(using selection: FamilyActivitySelection? = nil) {
        if EmergencyOverride.isActive() {
            clear()
            return
        }

        let picker = selection ?? ActivitySelectionStore.load()
        let lockedNames = UsageStore.loadLockedApps()
        let tokenByName = TokenIndex.tokensByName(from: picker)
        UsageStore.saveTokens(tokenByName)

        let stored = LockedTokenStore.load()
        let tokens = LockedShieldSet.applicationTokens(
            lockedNames: lockedNames,
            storedTokens: stored,
            tokenByName: tokenByName
        )

        // Never wipe a resolved lock set just because a later lookup failed.
        if tokens.isEmpty, !lockedNames.isEmpty, !stored.isEmpty {
            apply(tokens: stored)
            return
        }

        LockedTokenStore.save(tokens)
        apply(tokens: tokens)
    }

    /// Isolate the chosen tokens on the shield. Categories are left untouched
    /// so one locked app cannot take the rest of the home screen with it.
    static func apply(tokens: Set<ApplicationToken>) {
        let limited = Set(Array(tokens.subtracting(ExcludedApps.tokens)).prefix(50))
        store.clearAllSettings()
        guard !limited.isEmpty else { return }
        store.shield.applications = limited
    }

    static func clear() {
        store.clearAllSettings()
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

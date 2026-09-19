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

    static func setSharedDouble(_ value: Double, forKey key: String) {
        defaults.set(value, forKey: key)
        if let url = fileURL(for: key),
           let data = String(value).data(using: .utf8) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func sharedDouble(forKey key: String) -> Double? {
        if let url = fileURL(for: key),
           let data = try? Data(contentsOf: url),
           let raw = String(data: data, encoding: .utf8),
           let value = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return value
        }
        if defaults.object(forKey: key) != nil {
            return defaults.double(forKey: key)
        }
        return nil
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
        "com.Jacob-Scheff.Locked.ShieldAction",
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

/// Keys and Karma. Mirrored into the app-group container so shield
/// extensions can read them even when cfprefsd refuses the suite.
enum Economy {
    static let keysKey = "keys"
    static let karmaKey = "karma"
    static let defaultKeys: Double = 0
    static let defaultKarma: Double = 100

    /// First launch / first download. Existing stored values, including an
    /// explicit 0, are left alone. Only the main app should call this — a
    /// shield extension that cannot see the suite would otherwise write
    /// defaults on top of a real balance.
    static func seedNewInstallIfNeeded() {
        AppGroupStore.prepareContainer()
        let defaults = AppGroupStore.defaults
        if defaults.object(forKey: karmaKey) == nil && AppGroupStore.sharedDouble(forKey: karmaKey) == nil {
            setKarma(defaultKarma)
        } else {
            setKarma(karma())
        }
        if defaults.object(forKey: keysKey) != nil || AppGroupStore.sharedDouble(forKey: keysKey) != nil {
            setKeys(keys())
        }
    }

    static func keys() -> Double {
        clampKeys(AppGroupStore.sharedDouble(forKey: keysKey) ?? defaultKeys)
    }

    static func karma() -> Double {
        clampKarma(AppGroupStore.sharedDouble(forKey: karmaKey) ?? defaultKarma)
    }

    static func setKeys(_ value: Double) {
        AppGroupStore.setSharedDouble(clampKeys(value), forKey: keysKey)
    }

    static func setKarma(_ value: Double) {
        AppGroupStore.setSharedDouble(clampKarma(value), forKey: karmaKey)
    }

    @discardableResult
    static func spendKeys(_ amount: Double) -> Bool {
        let current = keys()
        guard amount > 0, current + 0.000_1 >= amount else { return false }
        setKeys(current - amount)
        return true
    }
}

func clampKeys(_ value: Double) -> Double {
    max(0, value)
}

func clampKarma(_ value: Double) -> Double {
    min(100, max(0, value))
}

/// Spend Keys to lift one shielded app. Used by Home and by the system shield.
enum KeyUnlock {
    enum Outcome: Equatable {
        case unlocked
        case notEnoughKeys(have: Int, need: Int)
        case notLocked
    }

    static func cost(forName name: String) -> Int {
        cost(usageSeconds: UsageStore.loadAppCounts()[name] ?? 0, lockedCount: LockedTokenStore.load().count)
    }

    static func cost(for token: ApplicationToken) -> Int {
        let name = UsageStore.displayName(for: token)
        return cost(
            usageSeconds: name.flatMap { UsageStore.loadAppCounts()[$0] } ?? 0,
            lockedCount: LockedTokenStore.load().count
        )
    }

    static func cost(usageSeconds: Int, lockedCount: Int) -> Int {
        let counts = UsageStore.loadAppCounts()
        let total = Double(counts.values.reduce(0, +))
        let usagePercentage = total > 0 ? (Double(usageSeconds) / total) * 100.0 : 0.0
        let raw = pow(Double(lockedCount), 1.5) + 0.5 * pow(usagePercentage, 1.25) + 10.0
        return max(1, Int(raw.rounded()))
    }

    static func canAfford(_ token: ApplicationToken) -> Bool {
        Int(Economy.keys().rounded(.towardZero)) >= cost(for: token)
    }

    @discardableResult
    static func unlock(token: ApplicationToken) -> Outcome {
        guard LockedTokenStore.load().contains(token) else { return .notLocked }
        let need = cost(for: token)
        let have = Int(Economy.keys().rounded(.towardZero))
        guard Economy.spendKeys(Double(need)) else {
            return .notEnoughKeys(have: have, need: need)
        }
        LockedTokenStore.remove(token)
        UsageStore.syncLockedNames()
        ScreenTimeShields.sync()
        UsageStore.pingMainApp()
        return .unlocked
    }
}

/// Two-step unlock on the system shield. The configuration extension
/// cannot show an alert, so the first tap only arms a short-lived prompt
/// and `.defer` redraws the shield as a confirm screen.
enum ShieldUnlockPrompt {
    static let tokenKey = "shieldUnlockPromptToken"
    static let untilKey = "shieldUnlockPromptUntil"
    static let armedAtKey = "shieldUnlockPromptArmedAt"
    static let duration: TimeInterval = 45
    /// Long enough that a double-tap on Use keys cannot hit Confirm.
    static let confirmDelay: TimeInterval = 0.9

    static func isConfirming(_ token: ApplicationToken) -> Bool {
        let until = AppGroupStore.sharedDouble(forKey: untilKey) ?? 0
        guard until > 0 else { return false }
        if Date().timeIntervalSince1970 >= until {
            clear()
            return false
        }
        guard let data = AppGroupStore.sharedData(forKey: tokenKey),
              let saved = TokenCoding.decode(ApplicationToken.self, from: data)
        else {
            return false
        }
        return saved == token
    }

    static func canConfirm(_ token: ApplicationToken) -> Bool {
        guard isConfirming(token) else { return false }
        let armedAt = AppGroupStore.sharedDouble(forKey: armedAtKey) ?? 0
        return Date().timeIntervalSince1970 - armedAt >= confirmDelay
    }

    static func begin(_ token: ApplicationToken) {
        guard let data = TokenCoding.encode(token) else { return }
        AppGroupStore.setSharedData(data, forKey: tokenKey)
        AppGroupStore.setSharedDouble(
            Date().addingTimeInterval(duration).timeIntervalSince1970,
            forKey: untilKey
        )
        AppGroupStore.setSharedDouble(Date().timeIntervalSince1970, forKey: armedAtKey)
    }

    static func clear() {
        if let url = AppGroupStore.fileURL(for: tokenKey) {
            try? FileManager.default.removeItem(at: url)
        }
        AppGroupStore.defaults.removeObject(forKey: tokenKey)
        AppGroupStore.setSharedDouble(0, forKey: untilKey)
        AppGroupStore.setSharedDouble(0, forKey: armedAtKey)
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

    static let lockedAppsKey = "lockedApps"

    /// Display names for the tokens that are actually shielded. Names are
    /// derived from `LockedTokenStore`, never stored on their own, so the
    /// list can't drift from what SpringBoard is enforcing.
    static func loadLockedApps() -> [String] {
        lockedNames(for: LockedTokenStore.load(), tokenMap: loadTokenMap())
    }

    static func lockedNames(for tokens: Set<ApplicationToken>, tokenMap: [String: ApplicationToken]) -> [String] {
        let ids = Set(tokens.map { TokenCoding.id(for: $0) })
        let names = tokenMap.compactMap { name, token in
            ids.contains(TokenCoding.id(for: token)) ? name : nil
        }
        return ExcludedApps.strippingExcluded(names).sorted()
    }

    /// Rewrites the cached `lockedApps` list from the shielded token set and
    /// returns it. Call after any change to `LockedTokenStore` or the token map.
    @discardableResult
    static func syncLockedNames() -> [String] {
        let names = loadLockedApps()
        if let raw = AppGroupStore.encodeJSON(names) {
            AppGroupStore.setSharedString(raw, forKey: lockedAppsKey)
        }
        return names
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

    /// Full display name cached by Screen Time extensions. The main app cannot
    /// read a token's name itself.
    static func displayName(for token: ApplicationToken) -> String? {
        let wanted = TokenCoding.id(for: token)
        return loadTokenMap().first { TokenCoding.id(for: $0.value) == wanted }?.key
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
        // Keep a name→token entry while the app has usage or is shielded, so
        // a locked app with zero time this week still shows its name.
        let lockedTokenSet = LockedTokenStore.load()
        let filteredTokens = mergedTokens.filter { name, data in
            if remainingNames.contains(name) { return true }
            guard let token = TokenCoding.decode(ApplicationToken.self, from: data) else { return false }
            return lockedTokenSet.contains(token)
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
        syncLockedNames()
        // The report extension never decides what is locked; it only
        // re-asserts the current token set now that names are known.
        ScreenTimeShields.sync()
        pingMainApp()
    }

    static func unlock(name: String) {
        if let token = loadTokenMap()[name] ?? token(for: name) {
            LockedTokenStore.remove(token)
        }
        syncLockedNames()
        ScreenTimeShields.sync()
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

    /// Drops shielded tokens the user has removed from the picker so an app
    /// can't stay locked after it is no longer managed.
    static func prune(to selection: FamilyActivitySelection) {
        var allowed = selection.applicationTokens
        if !selection.categoryTokens.isEmpty {
            // Category picks made before includeEntireCategory only expose
            // their apps through the usage report's token map.
            allowed.formUnion(UsageStore.loadTokenMap().values)
        }
        guard !allowed.isEmpty else { return }
        let current = load()
        let kept = current.intersection(allowed)
        if kept != current {
            save(kept)
        }
    }

    static func unnamedApps(excludingNames names: [String]) -> [UnnamedLockedApp] {
        let map = UsageStore.loadTokenMap()
        let namedIDs = Set(names.compactMap { map[$0] }.map { TokenCoding.id(for: $0) })
        return load()
            .filter { !namedIDs.contains(TokenCoding.id(for: $0)) }
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

    /// Replaces the shielded set with exactly these application tokens and
    /// rewrites the derived name list. An empty set unlocks everything.
    static func lock(tokens: Set<ApplicationToken>) {
        let isolated = isolatedTokens(from: tokens)
        LockedTokenStore.save(isolated)
        UsageStore.syncLockedNames()
        sync()
    }

    /// Makes SpringBoard match `LockedTokenStore`, honouring the emergency override.
    static func sync() {
        if EmergencyOverride.isActive() {
            clear()
            return
        }
        let isolated = isolatedTokens(from: LockedTokenStore.load())
        if isolated.isEmpty {
            clear()
        } else {
            apply(isolated)
        }
    }

    /// Shields only these application tokens. Categories and web domains are
    /// never applied — that would lock every app in a group instead of the
    /// specific apps karma picked.
    private static func apply(_ tokens: Set<ApplicationToken>) {
        guard !tokens.isEmpty else { return }
        // Do not call clearAllSettings() here. That write is applied
        // asynchronously and can wipe the assignment that follows, which
        // leaves the UI saying "Locked" while SpringBoard has no shield.
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        if store.shield.applications != tokens {
            store.shield.applications = tokens
        }
        clearLegacyDefaultStore()
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

    static func clear() {
        if store.shield.applications != nil {
            store.shield.applications = nil
        }
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        clearLegacyDefaultStore()
    }

    /// Shields written to the unnamed store by older builds outlive app
    /// updates and would keep apps locked with nothing in our lists.
    private static func clearLegacyDefaultStore() {
        let legacy = ManagedSettingsStore()
        if legacy.shield.applications != nil {
            legacy.shield.applications = nil
        }
        if legacy.shield.applicationCategories != nil {
            legacy.shield.applicationCategories = nil
        }
        if legacy.shield.webDomains != nil {
            legacy.shield.webDomains = nil
        }
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

    /// Schedules `intervalDidEnd(.emergencyOverride)` so shields come back
    /// even if the app is never reopened. Full calendar components are used
    /// because an hour/minute-only window that crosses midnight has an end
    /// before its start and is rejected or never fires.
    @discardableResult
    static func startEmergencyOverrideWindow(until expiry: Date) -> Bool {
        let calendar = Calendar.current
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        // Device Activity requires at least a 15 minute interval.
        let minimumEnd = Date().addingTimeInterval(15 * 60 + 5)
        let end = max(expiry, minimumEnd)
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: Date()),
            intervalEnd: calendar.dateComponents(components, from: end),
            repeats: false
        )
        let center = DeviceActivityCenter()
        center.stopMonitoring([.emergencyOverride])
        do {
            try center.startMonitoring(.emergencyOverride, during: schedule)
            return true
        } catch {
            print("Failed to start emergency override schedule: \(error)")
            return false
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
        let until = untilTimestamp(defaults: defaults)
        return max(0, Date(timeIntervalSince1970: until).timeIntervalSince(date))
    }

    /// The expiry as a Unix timestamp, or 0 when no override is stored.
    /// Extensions can fail to read the app-group suite through cfprefsd, so
    /// the value is mirrored into the group container and preferred from there.
    static func untilTimestamp(defaults: UserDefaults? = AppGroupStore.defaults) -> Double {
        if let url = AppGroupStore.fileURL(for: untilKey),
           let data = try? Data(contentsOf: url),
           let raw = String(data: data, encoding: .utf8),
           let mirrored = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return mirrored
        }
        return defaults?.double(forKey: untilKey) ?? 0
    }

    /// Writes the expiry to both the suite (as a Double, for @AppStorage
    /// observers and the widget) and the group container (for extensions).
    static func setUntil(_ timestamp: Double) {
        AppGroupStore.defaults.set(timestamp, forKey: untilKey)
        if let url = AppGroupStore.fileURL(for: untilKey),
           let data = String(timestamp).data(using: .utf8) {
            try? data.write(to: url, options: .atomic)
        }
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

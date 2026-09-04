//
//  ScreenTimeLockManager.swift
//  Locked
//
//  Applies real Screen Time shields. Authorization alone does nothing —
//  apps stay open until ManagedSettingsStore.shield is written.
//

import Combine
import FamilyControls
import Foundation
import ManagedSettings
import SwiftUI

extension ManagedSettingsStore.Name {
    static let locked = ManagedSettingsStore.Name("com.Jacob-Scheff.Locked.shields")
}

struct ScreenTimeLockedItems: Codable, Equatable {
    var applications: Set<ApplicationToken> = []
    var categories: Set<ActivityCategoryToken> = []
    var webDomains: Set<WebDomainToken> = []

    var isEmpty: Bool {
        applications.isEmpty && categories.isEmpty && webDomains.isEmpty
    }

    var count: Int {
        applications.count + categories.count + webDomains.count
    }
}

@MainActor
final class ScreenTimeLockManager: ObservableObject {
    static let shared = ScreenTimeLockManager()

    private let defaults = UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked")!
    private let settingsStore = ManagedSettingsStore(named: .locked)

    private let selectionKey = "screenTimeActivitySelection"
    private let lockedItemsKey = "screenTimeLockedItems"

    @Published var authorizationStatus: AuthorizationStatus
    @Published var selection: FamilyActivitySelection {
        didSet { persistSelection() }
    }
    @Published private(set) var lockedItems: ScreenTimeLockedItems

    var isAuthorized: Bool { authorizationStatus == .approved }

    var managedItemCount: Int {
        selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    var hasManagedApps: Bool { managedItemCount > 0 }

    private init() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        selection = Self.loadSelection(from: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
        lockedItems = Self.loadLockedItems(from: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            print("Screen Time authorization failed: \(error.localizedDescription)")
        }
        refreshAuthorizationStatus()
        applyShields()
    }

    func bootstrap() {
        refreshAuthorizationStatus()
        adoptNamedLocksIfNeeded()
        applyShields()
    }

    /// If the UI already lists locked app names but no tokens are shielded yet,
    /// adopt the current selection so those locks start blocking immediately.
    func adoptNamedLocksIfNeeded() {
        guard isAuthorized, hasManagedApps, lockedItems.isEmpty else { return }
        let names = LogicStore.shared.lockedApps
        guard !names.isEmpty else { return }

        let pool = lockableItems()
        var picked = ScreenTimeLockedItems()
        for item in pool where item.matches(names: names) {
            picked.insert(item)
        }
        if picked.isEmpty {
            for item in pool.prefix(names.count) {
                picked.insert(item)
            }
        }
        lockedItems = picked
        persistLockedItems()
    }

    // MARK: - Weekly lock

    /// Picks managed Screen Time items to shield, using karma and any Shortcut usage names.
    func lockForWeeklyKarma(lockedNames: [String], karma: Double) {
        guard isAuthorized, hasManagedApps else {
            if !hasManagedApps {
                lockedItems = ScreenTimeLockedItems()
                persistLockedItems()
            }
            applyShields()
            return
        }

        let pool = lockableItems()
        let lockPercent = max(0.0, min(100.0, 100.0 - karma))
        let numToLock = Int((lockPercent / 100.0 * Double(pool.count)).rounded(.up))

        var snapshot: [String: Int] = [:]
        var itemsByID: [String: LockableItem] = [:]
        for item in pool {
            itemsByID[item.id] = item
            snapshot[item.id] = frequency(for: item, lockedNames: lockedNames)
        }

        var picked = ScreenTimeLockedItems()
        var working = snapshot

        // Prefer tokens whose display name is already in the name-based lock list.
        for item in pool where item.matches(names: lockedNames) {
            picked.insert(item)
            working.removeValue(forKey: item.id)
        }

        while picked.count < numToLock, !working.isEmpty {
            let id = lockAppByKarma(from: working)
            guard !id.isEmpty, let item = itemsByID[id] else { break }
            picked.insert(item)
            working.removeValue(forKey: id)
        }

        lockedItems = picked
        persistLockedItems()
        applyShields()
    }

    func unlockApplication(_ token: ApplicationToken) {
        lockedItems.applications.remove(token)
        if let name = displayName(for: token) {
            var names = LogicStore.shared.lockedApps
            names.removeAll { $0 == name }
            LogicStore.shared.lockedApps = names
        }
        persistLockedItems()
        applyShields()
    }

    func unlockCategory(_ token: ActivityCategoryToken) {
        lockedItems.categories.remove(token)
        persistLockedItems()
        applyShields()
    }

    func unlockWebDomain(_ token: WebDomainToken) {
        lockedItems.webDomains.remove(token)
        persistLockedItems()
        applyShields()
    }

    func unlock(name: String) {
        if let token = applicationToken(matching: name) {
            lockedItems.applications.remove(token)
        } else if lockedItems.applications.count > LogicStore.shared.lockedApps.count {
            // Name didn't map; keep token count aligned with remaining named locks.
            lockedItems.applications = Set(lockedItems.applications.prefix(LogicStore.shared.lockedApps.count))
        }
        persistLockedItems()
        applyShields()
    }

    func clearAllLocks() {
        lockedItems = ScreenTimeLockedItems()
        persistLockedItems()
        applyShields()
    }

    /// Re-reads override + locked items and writes the matching ManagedSettings shields.
    func applyShields() {
        refreshAuthorizationStatus()
        pruneLockedItemsToSelection()

        guard isAuthorized else {
            settingsStore.clearAllSettings()
            return
        }

        if LogicStore.shared.isEmergencyOverrideActive {
            settingsStore.shield.applications = nil
            settingsStore.shield.applicationCategories = nil
            settingsStore.shield.webDomains = nil
            return
        }

        // Screen Time accepts at most 50 application shields at once.
        let applicationShields = Set(lockedItems.applications.prefix(50))
        settingsStore.shield.applications = applicationShields.isEmpty
            ? nil
            : applicationShields
        settingsStore.shield.applicationCategories = lockedItems.categories.isEmpty
            ? nil
            : .specific(lockedItems.categories)
        settingsStore.shield.webDomains = lockedItems.webDomains.isEmpty
            ? nil
            : lockedItems.webDomains
    }

    func displayName(for token: ApplicationToken) -> String? {
        // Names are only available in Screen Time extensions, not the main app.
        ManagedSettings.Application(token: token).localizedDisplayName
    }

    // MARK: - Persistence

    func persistSelection() {
        if let data = ScreenTimeCoding.encode(selection) {
            defaults.set(data, forKey: selectionKey)
        }
    }

    private func pruneLockedItemsToSelection() {
        let pruned = ScreenTimeLockedItems(
            applications: lockedItems.applications.intersection(selection.applicationTokens),
            categories: lockedItems.categories.intersection(selection.categoryTokens),
            webDomains: lockedItems.webDomains.intersection(selection.webDomainTokens)
        )
        guard pruned != lockedItems else { return }
        lockedItems = pruned
        persistLockedItems()
    }

    private func persistLockedItems() {
        if let data = ScreenTimeCoding.encode(lockedItems) {
            defaults.set(data, forKey: lockedItemsKey)
        }
        objectWillChange.send()
    }

    private static func loadSelection(from defaults: UserDefaults?) -> FamilyActivitySelection {
        let empty = FamilyActivitySelection(includeEntireCategory: true)
        guard let data = defaults?.data(forKey: "screenTimeActivitySelection"),
              let decoded = ScreenTimeCoding.decode(FamilyActivitySelection.self, from: data)
        else { return empty }
        return decoded
    }

    private static func loadLockedItems(from defaults: UserDefaults?) -> ScreenTimeLockedItems {
        guard let data = defaults?.data(forKey: "screenTimeLockedItems"),
              let decoded = ScreenTimeCoding.decode(ScreenTimeLockedItems.self, from: data)
        else { return ScreenTimeLockedItems() }
        return decoded
    }

    // MARK: - Matching

    private func lockableItems() -> [LockableItem] {
        var items: [LockableItem] = []
        for token in selection.applicationTokens {
            items.append(.application(token, name: displayName(for: token)))
        }
        for token in selection.categoryTokens {
            items.append(.category(token))
        }
        for token in selection.webDomainTokens {
            items.append(.webDomain(token))
        }
        return items
    }

    private func frequency(for item: LockableItem, lockedNames: [String]) -> Int {
        if let name = item.displayName, let usage = LogicStore.shared.appCounts[name] {
            return max(usage, 1)
        }
        if item.matches(names: lockedNames) {
            return 2
        }
        return 1
    }

    private func applicationToken(matching name: String) -> ApplicationToken? {
        selection.applicationTokens.first { token in
            ManagedSettings.Application(token: token).localizedDisplayName?.caseInsensitiveCompare(name) == .orderedSame
        }
    }
}

private enum LockableItem: Hashable {
    case application(ApplicationToken, name: String?)
    case category(ActivityCategoryToken)
    case webDomain(WebDomainToken)

    var id: String {
        switch self {
        case .application(let token, _):
            return "app:" + ScreenTimeCoding.id(for: token)
        case .category(let token):
            return "cat:" + ScreenTimeCoding.id(for: token)
        case .webDomain(let token):
            return "web:" + ScreenTimeCoding.id(for: token)
        }
    }

    var displayName: String? {
        switch self {
        case .application(_, let name): return name
        default: return nil
        }
    }

    func matches(names: [String]) -> Bool {
        guard let displayName else { return false }
        return names.contains(where: { $0.caseInsensitiveCompare(displayName) == .orderedSame })
    }
}

private extension ScreenTimeLockedItems {
    mutating func insert(_ item: LockableItem) {
        switch item {
        case .application(let token, _): applications.insert(token)
        case .category(let token): categories.insert(token)
        case .webDomain(let token): webDomains.insert(token)
        }
    }
}

func tokenSort<T: Encodable>(_ lhs: T, _ rhs: T) -> Bool {
    ScreenTimeCoding.id(for: lhs) < ScreenTimeCoding.id(for: rhs)
}

enum ScreenTimeCoding {
    static func encode<T: Encodable>(_ value: T) -> Data? {
        if let data = try? PropertyListEncoder().encode(value) { return data }
        return try? JSONEncoder().encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        if let value = try? PropertyListDecoder().decode(type, from: data) { return value }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func id<T: Encodable>(for value: T) -> String {
        guard let data = encode(value) else { return UUID().uuidString }
        return data.base64EncodedString()
    }
}

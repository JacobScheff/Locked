import FamilyControls
import ManagedSettings
import SwiftUI
import WidgetKit

struct MainPage: View {
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @EnvironmentObject private var sources: ExternalSourceController
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("screentime", store: .lockedGroup)
    var screentime: Int = 0

    @AppStorage("appCounts", store: .lockedGroup)
    var appCounts: [String: Int] = [:]

    @AppStorage("keys", store: .lockedGroup)
    var keys: Double = 0.0

    @AppStorage("karma", store: .lockedGroup)
    var karma: Double = 100.0

    @AppStorage("lockedApps", store: .lockedGroup)
    var lockedApps: [String] = []

    @AppStorage("courses", store: .lockedGroup)
    var courses: [Course] = []

    @AppStorage("emergencyOverrideUntil", store: .lockedGroup)
    var emergencyOverrideUntil: Double = 0

    @State private var now = Date()
    @State private var sourceError: String?

    private var overrideActive: Bool {
        Date(timeIntervalSince1970: emergencyOverrideUntil) > now
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if overrideActive {
                    OverrideStatusBanner(
                        compact: true,
                        onRestore: {
                            now = Date()
                            updateWidget()
                        },
                        onExpired: {
                            now = Date()
                            ScreenTimeShields.sync()
                            updateWidget()
                        }
                    )
                }

                if screenTime.isReady && screenTime.needsSetup {
                    ScreenTimeSetupCard(manager: screenTime)
                }

                LockedAppsSection(
                    lockedApps: $lockedApps,
                    keys: $keys,
                    karma: $karma,
                    appCounts: $appCounts,
                    overrideActive: overrideActive,
                    updateWidget: updateWidget
                )

                HomeCoursesSection(
                    courses: $courses,
                    keys: $keys,
                    karma: $karma,
                    refresh: refreshSources
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(LockedBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Locked")
                    .font(.headline.weight(.bold))
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsPage()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(red: 0.55, green: 0.56, blue: 0.78))
                        .frame(width: 38, height: 38)
                        .background {
                            Circle()
                                .fill(Color(uiColor: .systemBackground))
                                .shadow(color: Color.black.opacity(0.10), radius: 5, y: 2)
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .lockedRefreshable {
            refreshScreenTime()
            guard sources.canRefresh, !sources.isRefreshing else { return }
            await refreshSources()
        }
        .alert("Couldn’t refresh", isPresented: Binding(
            get: { sourceError != nil },
            set: { if !$0 { sourceError = nil } }
        )) {
            Button("OK", role: .cancel) { sourceError = nil }
        } message: {
            Text(sourceError ?? "")
        }
        .onAppear {
            now = Date()
            refreshScreenTime()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                now = Date()
                refreshScreenTime()
            }
        }
        .onChange(of: screenTime.isPickerPresented) { _, presented in
            if !presented {
                refreshScreenTime()
            }
        }
        .onChange(of: screenTime.usageRevision) { _, _ in
            applyUsageSnapshot()
        }
    }

    private func refreshSources() async {
        do {
            let result = try await sources.refreshConnectedSources(courses: courses, keys: keys, karma: karma)
            withAnimation {
                courses = result.courses
                keys = result.keys
                karma = result.karma
            }
        } catch {
            if ExternalSourceController.isCancellation(error) { return }
            sourceError = error.localizedDescription
        }
    }

    private func refreshScreenTime() {
        screenTime.refreshStatus()
        applyUsageSnapshot()
    }

    private func applyUsageSnapshot() {
        let newCounts: [String: Int]
        if UsageStore.hasSnapshot {
            newCounts = UsageStore.loadAppCounts()
        } else {
            newCounts = ExcludedApps.strippingExcluded(appCounts)
        }
        // Locked names always come from the shielded token set.
        let newLocked = UsageStore.syncLockedNames()
        if appCounts != newCounts {
            appCounts = newCounts
        }
        if lockedApps != newLocked {
            lockedApps = newLocked
        }
        let total = newCounts.values.reduce(0, +)
        if screentime != total {
            screentime = total
        }
    }

    func updateWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
    }
}

// MARK: - Karma ring + unlock ledger

struct HomeEconomyCard: View {
    let karma: Double
    let keys: Int
    let cost: Int?
    var overrideActive: Bool = false
    var appCount: Int = 0

    private var progress: Double {
        min(max(karma / 100.0, 0.0), 1.0)
    }

    private var copy: (headline: String, detail: String) {
        if overrideActive {
            return ("Temporarily open", "Locks return when the seal repairs.")
        }
        return karmaStatusCopy(karma: karma, appCount: appCount)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                ProgressRing(
                    progress: progress,
                    lineWidth: 11,
                    gradient: Color.lockedTeal.gradient,
                    trackOpacity: 0.22
                )
                VStack(spacing: 0) {
                    Text("\(Int(karma.rounded(.towardZero)))")
                        .font(.lockedNumber(30))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text("KARMA")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(1)
                }
            }
            .frame(width: 104, height: 104)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(Int(karma.rounded(.towardZero))) karma")

            if cost != nil {
                UnlockLedgerCard(keys: keys, cost: cost)
            } else {
                clearStatus
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LockedTheme.heroGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: Color.lockedIndigo.opacity(0.32), radius: 22, x: 0, y: 10)
        }
        .accessibilityElement(children: .combine)
    }

    private var clearStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy.headline)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(copy.detail)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.lockedAmber)
                Text(UnlockLedgerCard.format(keys, signed: false))
                    .font(.lockedNumber(20))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("Keys")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(copy.headline). \(copy.detail). \(keys) keys")
    }
}

struct UnlockLedgerCard: View {
    let keys: Int
    let cost: Int?
    var showsCardBackground: Bool = false
    var leftover: Int? {
        guard let cost else { return nil }
        return keys - cost
    }

    var body: some View {
        VStack(spacing: 0) {
            ledgerRow("Keys", subtitle: nil, value: keys, color: .lockedAmber, signed: false)
            if let cost {
                ledgerRow(
                    "Unlock",
                    subtitle: "until Sunday",
                    value: -cost,
                    color: .lockedRose,
                    signed: true
                )
                .padding(.top, 2)

                Rectangle()
                    .fill(Color.white.opacity(0.16))
                    .frame(height: 1)
                    .padding(.vertical, 8)

                ledgerRow("Left", subtitle: nil, value: leftover ?? 0, color: (leftover ?? 0) >= 0 ? .lockedTeal : .lockedRose, signed: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(showsCardBackground ? 18 : 0)
        .background {
            if showsCardBackground {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(red: 0.10, green: 0.09, blue: 0.20).gradient)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func ledgerRow(_ label: String, subtitle: String?, value: Int, color: Color, signed: Bool) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.62))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }
            Spacer(minLength: 10)
            Text(UnlockLedgerCard.format(value, signed: signed))
                .font(.lockedNumber(24))
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.vertical, 3)
    }

    private var accessibilityText: String {
        if let cost, let leftover {
            return "\(keys) keys, \(cost) keys to unlock an app until Sunday, \(leftover) left"
        }
        return "\(keys) keys"
    }

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter
    }()

    static func format(_ value: Int, signed: Bool) -> String {
        let formatted = formatter.string(from: NSNumber(value: abs(value))) ?? "\(abs(value))"
        if signed {
            return value < 0 ? "−\(formatted)" : value > 0 ? "+\(formatted)" : formatted
        }
        return value < 0 ? "−\(formatted)" : formatted
    }
}

// MARK: - Locked apps

struct LockedAppsSection: View {
    @Binding var lockedApps: [String]
    @Binding var keys: Double
    @Binding var karma: Double
    @Binding var appCounts: [String: Int]
    var overrideActive: Bool
    var updateWidget: () -> Void

    @State private var pendingUnlock: PendingUnlock?
    @State private var previewCost: Int?

    private var gridItems: [LockedGridItem] {
        let named = visibleLockedApps.map { LockedGridItem.named($0) }
        let unnamed = unnamedLockedTokens.map { LockedGridItem.unnamed($0) }
        return named + unnamed
    }

    private var displayedCost: Int? {
        if overrideActive || gridItems.isEmpty { return nil }
        if let pendingUnlock { return pendingUnlock.cost }
        if let previewCost { return previewCost }
        return gridItems.first?.cost
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeEconomyCard(
                karma: karma,
                keys: Int(keys.rounded(.towardZero)),
                cost: displayedCost,
                overrideActive: overrideActive,
                appCount: ExcludedApps.strippingExcluded(appCounts).count
            )

            if !gridItems.isEmpty {
                LockedSectionLabel(
                    title: overrideActive ? "Temporarily released" : "Locked apps",
                    icon: overrideActive ? "lock.open.fill" : "lock.fill"
                ) {
                    if !overrideActive {
                        Text("Tap to unlock")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 4),
                    spacing: 20
                ) {
                    ForEach(Array(gridItems.enumerated()), id: \.element.id) { index, item in
                        LockedAppIconButton(
                            item: item,
                            index: index,
                            overrideActive: overrideActive,
                            onHighlight: { highlighted in
                                withAnimation(.snappy(duration: 0.22)) {
                                    previewCost = highlighted ? item.cost : nil
                                }
                            },
                            onUnlock: {
                                previewCost = item.cost
                                pendingUnlock = PendingUnlock(item: item)
                            }
                        )
                    }
                }
                .padding(.horizontal, 2)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
        .sheet(item: $pendingUnlock, onDismiss: {
            previewCost = nil
        }) { pending in
            UnlockConfirmSheet(
                pending: pending,
                keys: Int(keys.rounded(.towardZero)),
                canAfford: keys >= Double(pending.cost),
                onUnlock: { confirmUnlock(pending) },
                onCancel: { pendingUnlock = nil }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.8), trigger: pendingUnlock?.id)
    }

    private func confirmUnlock(_ pending: PendingUnlock) {
        if let unnamed = pending.unnamedApp {
            _ = KeyUnlock.unlock(token: unnamed.token)
        } else if let name = pending.namedApp, let token = UsageStore.token(for: name) {
            _ = KeyUnlock.unlock(token: token)
        } else if let name = pending.namedApp {
            Economy.spendKeys(Double(pending.cost))
            UsageStore.unlock(name: name)
        }
        keys = Economy.keys()
        karma = Economy.karma()
        lockedApps = UsageStore.syncLockedNames()
        pendingUnlock = nil
        previewCost = nil
        updateWidget()
    }

    private var unnamedLockedTokens: [UnnamedLockedApp] {
        LockedTokenStore.unnamedApps(excludingNames: visibleLockedApps)
    }

    private var visibleLockedApps: [String] {
        ExcludedApps.strippingExcluded(lockedApps).sorted { lhs, rhs in
            let left = appCounts[lhs] ?? 0
            let right = appCounts[rhs] ?? 0
            return left == right ? lhs < rhs : left > right
        }
    }
}

private struct LockedGridItem: Identifiable {
    enum Kind {
        case named(String)
        case unnamed(UnnamedLockedApp)
    }

    let kind: Kind

    static func named(_ name: String) -> LockedGridItem {
        LockedGridItem(kind: .named(name))
    }

    static func unnamed(_ app: UnnamedLockedApp) -> LockedGridItem {
        LockedGridItem(kind: .unnamed(app))
    }

    var id: String {
        switch kind {
        case .named(let name): return "named:\(name)"
        case .unnamed(let app): return "unnamed:\(app.id)"
        }
    }

    var title: String? {
        switch kind {
        case .named(let name): return name
        case .unnamed: return nil
        }
    }

    var namedApp: String? {
        if case .named(let name) = kind { return name }
        return nil
    }

    var unnamedApp: UnnamedLockedApp? {
        if case .unnamed(let app) = kind { return app }
        return nil
    }

    var token: ApplicationToken? {
        switch kind {
        case .named(let name): return UsageStore.token(for: name)
        case .unnamed(let app): return app.token
        }
    }

    var cost: Int {
        if let token {
            return KeyUnlock.cost(for: token)
        }
        if let namedApp {
            return KeyUnlock.cost(forName: namedApp)
        }
        return KeyUnlock.cost(usageSeconds: 0, lockedCount: LockedTokenStore.load().count)
    }
}

private struct PendingUnlock: Identifiable {
    let id = UUID()
    let title: String
    let namedApp: String?
    let unnamedApp: UnnamedLockedApp?
    let token: ApplicationToken?
    let cost: Int

    init(item: LockedGridItem) {
        title = item.title ?? "Locked app"
        namedApp = item.namedApp
        unnamedApp = item.unnamedApp
        token = item.token
        cost = item.cost
    }
}

private struct LockedAppIconButton: View {
    let item: LockedGridItem
    let index: Int
    var overrideActive: Bool
    var onHighlight: (Bool) -> Void
    var onUnlock: () -> Void

    @State private var appeared = false

    private let iconSize: CGFloat = 64

    var body: some View {
        Button {
            guard !overrideActive else { return }
            onUnlock()
        } label: {
            VStack(spacing: 5) {
                floatingIcon
                titleView
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(HomeIconButtonStyle(onPressed: onHighlight))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .scaleEffect(appeared ? 1 : 0.84)
        .modifier(HomeIconFloat(phase: Double(index) * 0.85, active: appeared))
        .onAppear {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.7).delay(Double(index) * 0.045)) {
                appeared = true
            }
        }
        .contextMenu {
            if !overrideActive {
                Button("Unlock", systemImage: "key.fill", action: onUnlock)
            }
        }
        .accessibilityLabel(accessibilityName)
        .accessibilityHint(overrideActive ? "Temporarily available" : "Unlocks this app for keys")
    }

    private var floatingIcon: some View {
        ZStack(alignment: .bottomTrailing) {
            icon
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.2237, style: .continuous))

            Image(systemName: overrideActive ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(overrideActive ? Color.black.opacity(0.8) : .white)
                .padding(4)
                .background(
                    overrideActive ? Color.hazardYellow : Color.black.opacity(0.7),
                    in: Circle()
                )
                .offset(x: 3, y: 3)
        }
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 6)
        .shadow(color: Color.lockedIndigo.opacity(0.12), radius: 16, x: 0, y: 8)
    }

    @ViewBuilder
    private var titleView: some View {
        Group {
            if let token = item.token {
                Label(token)
                    .labelStyle(.titleOnly)
            } else if let title = item.title {
                Text(title)
            }
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .multilineTextAlignment(.center)
        .frame(maxWidth: iconSize + 8)
    }

    private var accessibilityName: String {
        let name = item.title ?? "Locked app"
        return overrideActive ? "\(name), released" : "\(name), locked"
    }

    @ViewBuilder
    private var icon: some View {
        if let token = item.token {
            Label(token)
                .labelStyle(.iconOnly)
                .scaleEffect(iconSize / 32)
        } else if let name = item.namedApp {
            AppIconView(appName: name)
        } else {
            RoundedRectangle(cornerRadius: iconSize * 0.2237, style: .continuous)
                .fill(Color.lockedIndigo.opacity(0.14))
                .overlay {
                    Image(systemName: "app.fill")
                        .foregroundStyle(Color.lockedIndigo)
                }
        }
    }
}

private struct HomeIconFloat: ViewModifier {
    let phase: Double
    var active: Bool

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !active)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let lift = active ? sin(t * 1.05 + phase) * 2.4 : 0
            content
                .offset(y: lift)
        }
    }
}

private struct HomeIconButtonStyle: ButtonStyle {
    var onPressed: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.56), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                onPressed(pressed)
            }
    }
}

private struct UnlockConfirmSheet: View {
    let pending: PendingUnlock
    let keys: Int
    let canAfford: Bool
    var onUnlock: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    confirmIcon
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.16), radius: 8, y: 4)

                    Text(pending.title)
                        .font(.title3.weight(.bold))
                    Text(canAfford
                         ? "Spend keys to unlock this app until Sunday."
                         : "Finish assignments to earn more keys.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                UnlockLedgerCard(keys: keys, cost: pending.cost, showsCardBackground: true)

                HStack(spacing: 10) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)

                    Button(action: onUnlock) {
                        Text(canAfford ? "Unlock" : "Not enough")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.lockedAmber)
                    .disabled(!canAfford)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(LockedBackground())
    }

    @ViewBuilder
    private var confirmIcon: some View {
        if let token = pending.token {
            Label(token)
                .labelStyle(.iconOnly)
                .scaleEffect(72.0 / 32.0)
        } else if let name = pending.namedApp {
            AppIconView(appName: name)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.lockedIndigo.opacity(0.14))
                .overlay {
                    Image(systemName: "app.fill")
                        .font(.title)
                        .foregroundStyle(Color.lockedIndigo)
                }
        }
    }
}

// MARK: - Screen Time setup

private struct ScreenTimeSetupCard: View {
    @ObservedObject var manager: ScreenTimeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "hourglass.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(LockedTheme.karmaGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Finish setup")
                        .font(.headline)
                    Text(manager.isAuthorized
                         ? "Choose the apps Locked is allowed to track and lock. Settings, Phone, and other safety apps stay out automatically."
                         : "Allow Screen Time so Locked can track usage and lock apps for you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                if manager.isAuthorized {
                    manager.presentPicker()
                } else {
                    Task { await manager.requestAuthorization() }
                }
            } label: {
                Text(manager.isAuthorized ? "Choose Apps" : "Allow Screen Time")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LockedTheme.karmaGradient)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(LockedCardBackground())
    }
}

// MARK: - App usage

struct AppCountsCard: View {
    @Binding var appCounts: [String: Int]
    @Binding var lockedApps: [String]
    var overrideActive: Bool = false

    private var visibleAppCounts: [String: Int] {
        ExcludedApps.strippingExcluded(appCounts)
    }

    var totalAppCounts: Double { Double(visibleAppCounts.values.reduce(0, +)) }

    private var displayOrder: [String] {
        visibleAppCounts.keys.sorted { lhs, rhs in
            let left = visibleAppCounts[lhs] ?? 0
            let right = visibleAppCounts[rhs] ?? 0
            return left == right ? lhs < rhs : left > right
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LockedSectionLabel(
                title: "App usage",
                icon: "chart.bar.fill"
            )

            VStack(alignment: .leading, spacing: 0) {
                if visibleAppCounts.isEmpty {
                    Text("Usage appears after you spend time in the apps Locked is allowed to manage.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(displayOrder.enumerated()), id: \.element) { index, name in
                            let isLocked = lockedApps.contains(name)

                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(.caption, design: .rounded, weight: .bold))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 22, alignment: .leading)

                                    ManagedAppIcon(name: name, size: 32)

                                    Text(name)
                                        .font(.system(.body, design: .rounded, weight: .medium))
                                        .lineLimit(1)

                                    Spacer()

                                    if isLocked {
                                        VStack(alignment: .trailing, spacing: 3) {
                                            Label(overrideActive ? "Released" : "Locked", systemImage: overrideActive ? "lock.open.fill" : "lock.fill")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(overrideActive ? Color.hazardYellow : Color.secondary)
                                                .labelStyle(.titleAndIcon)
                                            Text(formatAppDuration(visibleAppCounts[name] ?? 0))
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        let count = Double(visibleAppCounts[name] ?? 0)
                                        let percentage = totalAppCounts > 0 ? count / totalAppCounts : 0
                                        AppUsageBar(seconds: visibleAppCounts[name] ?? 0, percentage: percentage)
                                            .frame(width: 108)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 62)

                                if name != displayOrder.last {
                                    Divider().padding(.leading, 70)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .background(LockedCardBackground())
        }
    }
}

struct AppUsageBar: View {
    let seconds: Int
    let percentage: Double

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(formatAppDuration(seconds))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Color.lockedIndigo.gradient)
                        .frame(width: max(geo.size.width * CGFloat(percentage), 4))
                }
            }
            .frame(height: 7)

            Text("\(Int(percentage * 100))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

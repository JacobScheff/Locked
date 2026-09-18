import FamilyControls
import ManagedSettings
import SwiftUI
import WidgetKit

struct MainPage: View {
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("screentime", store: .lockedGroup)
    var screentime: Int = 0
    var days: Int { screentime / 86400 }
    var hours: Int { (screentime % 86400) / 3600 }
    var minutes: Int { (screentime % 3600) / 60 }

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

    @AppStorage("innerVaultUnlockedUntil", store: .lockedGroup)
    var innerVaultUnlockedUntil: Double = 0

    @State private var presentedRitual: HomeRitual?
    @State private var now = Date()

    private var overrideActive: Bool {
        Date(timeIntervalSince1970: emergencyOverrideUntil) > now
    }

    private var vaultUnlocked: Bool {
        overrideActive && innerVaultUnlockedUntil > 0 && abs(innerVaultUnlockedUntil - emergencyOverrideUntil) < 0.5
    }

    private var upcomingItems: [(course: Course, assignment: Assignment)] {
        courses.flatMap { course in
            course.assignments
                .filter { !$0.isCompleted }
                .map { (course, $0) }
        }
        .sorted { $0.assignment.dueDate < $1.assignment.dueDate }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                if overrideActive {
                    OverrideStatusBanner(
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

                StatusHero(
                    karma: karma,
                    keys: keys,
                    days: days,
                    hours: hours,
                    minutes: minutes,
                    appCount: visibleAppCounts.count
                )

                if screenTime.isReady && screenTime.needsSetup {
                    ScreenTimeSetupCard(manager: screenTime)
                }

                LockedAppsSection(
                    lockedApps: $lockedApps,
                    keys: $keys,
                    appCounts: $appCounts,
                    overrideActive: overrideActive,
                    updateWidget: updateWidget
                )

                if !upcomingItems.isEmpty {
                    UpcomingSection(items: Array(upcomingItems.prefix(3)), courses: $courses)
                }

                AppCountsCard(
                    appCounts: $appCounts,
                    lockedApps: $lockedApps,
                    overrideActive: overrideActive
                )

                if overrideActive {
                    VaultSealCard(unlocked: vaultUnlocked) {
                        presentedRitual = .vault
                    }
                } else {
                    EmergencySealCard {
                        presentedRitual = .glass
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(LockedBackground())
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $presentedRitual) { ritual in
            switch ritual {
            case .glass:
                BreakGlassView {
                    now = Date()
                    updateWidget()
                }
            case .vault:
                InnerVaultView {
                    updateWidget()
                }
            }
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

    private var visibleAppCounts: [String: Int] {
        ExcludedApps.strippingExcluded(appCounts)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Greeting.current)
                .font(.lockedTitle(32))
                .foregroundStyle(.primary)
            Text(overrideActive ? "Emergency override is active" : WeeklyLock.subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(overrideActive ? Color.hazardRed : Color.secondary)
        }
    }

    func updateWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
    }
}

private enum HomeRitual: String, Identifiable {
    case glass
    case vault

    var id: String { rawValue }
}

// MARK: - Header / Hero

private struct StatusHero: View {
    let karma: Double
    let keys: Double
    let days: Int
    let hours: Int
    let minutes: Int
    let appCount: Int

    private var progress: Double {
        min(max(karma / 100.0, 0.0), 1.0)
    }

    private var copy: (headline: String, detail: String) {
        karmaStatusCopy(karma: karma, appCount: appCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    ProgressRing(
                        progress: progress,
                        lineWidth: 11,
                        gradient: LinearGradient(
                            colors: [.white, Color.lockedTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        trackOpacity: 0.22
                    )
                    VStack(spacing: 0) {
                        Text("\(Int(karma))")
                            .font(.lockedNumber(34))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                        Text("KARMA")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .tracking(1)
                    }
                }
                .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: 8) {
                    Text(copy.headline)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(copy.detail)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                HeroMetric(
                    icon: "key.fill",
                    value: "\(Int(keys))",
                    label: "Keys",
                    iconColor: .lockedAmber
                )
                HeroMetric(
                    icon: "hourglass",
                    value: formatScreenTime(days: days, hours: hours, minutes: minutes),
                    label: "Screen time",
                    iconColor: .lockedTeal
                )
            }
        }
        .padding(22)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LockedTheme.heroGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: Color.lockedIndigo.opacity(0.35), radius: 24, x: 0, y: 12)
        }
    }
}

private struct HeroMetric: View {
    let icon: String
    let value: String
    let label: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.lockedNumber(18))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

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

// MARK: - Locked apps

struct LockedAppsSection: View {
    @Binding var lockedApps: [String]
    @Binding var keys: Double
    @Binding var appCounts: [String: Int]
    var overrideActive: Bool
    var updateWidget: () -> Void

    @State private var showUnlockAlert = false
    @State private var appToUnlock: String?
    @State private var unnamedAppToUnlock: UnnamedLockedApp?
    @State private var unlockCost: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LockedSectionLabel(
                title: overrideActive ? "Temporarily released" : "Locked apps",
                icon: overrideActive ? "lock.open.fill" : "lock.fill"
            )

            if visibleLockedApps.isEmpty && unnamedLockedTokens.isEmpty {
                LockedCard {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundStyle(Color.lockedTeal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nothing is locked")
                                .font(.headline)
                            Text("Keep karma high and assignments on time to stay clear.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(unnamedLockedTokens) { item in
                        LockedAppRow(
                            title: "Locked app",
                            duration: nil,
                            cost: KeyUnlock.cost(for: item.token),
                            overrideActive: overrideActive,
                            icon: { UnnamedLockedAppLabel(app: item).labelStyle(.iconOnly) }
                        ) {
                            appToUnlock = "this app"
                            unlockCost = KeyUnlock.cost(for: item.token)
                            unnamedAppToUnlock = item
                            showUnlockAlert = true
                        }
                    }
                    ForEach(visibleLockedApps, id: \.self) { name in
                        LockedAppRow(
                            title: name,
                            duration: formatAppDuration(appCounts[name] ?? 0),
                            cost: KeyUnlock.cost(forName: name),
                            overrideActive: overrideActive,
                            icon: { ManagedAppIcon(name: name, size: 44) }
                        ) {
                            appToUnlock = name
                            unlockCost = KeyUnlock.cost(forName: name)
                            unnamedAppToUnlock = nil
                            showUnlockAlert = true
                        }
                    }
                }
            }
        }
        .alert(
            keys >= Double(unlockCost) ? "Spend \(unlockCost) keys?" : "Not enough keys",
            isPresented: $showUnlockAlert,
            presenting: appToUnlock
        ) { app in
            if keys >= Double(unlockCost) {
                Button("Confirm unlock") {
                    if let unnamed = unnamedAppToUnlock {
                        _ = KeyUnlock.unlock(token: unnamed.token)
                        unnamedAppToUnlock = nil
                    } else if let token = UsageStore.token(for: app) {
                        _ = KeyUnlock.unlock(token: token)
                    } else {
                        Economy.spendKeys(Double(unlockCost))
                        UsageStore.unlock(name: app)
                    }
                    keys = Economy.keys()
                    lockedApps = UsageStore.syncLockedNames()
                    updateWidget()
                }
                Button("Cancel", role: .cancel) { }
            } else {
                Button("OK", role: .cancel) { }
            }
        } message: { app in
            if keys >= Double(unlockCost) {
                Text("Unlock \(app) until next Sunday. You’ll have \(max(0, Int(keys) - unlockCost)) keys left.")
            } else {
                Text("\(app) needs \(unlockCost) keys, but you only have \(Int(keys)). Finish assignments to earn more.")
            }
        }
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

private struct LockedAppRow<Icon: View>: View {
    let title: String
    var duration: String?
    let cost: Int
    var overrideActive: Bool
    let icon: Icon
    var onUnlock: () -> Void

    init(
        title: String,
        duration: String? = nil,
        cost: Int,
        overrideActive: Bool,
        @ViewBuilder icon: () -> Icon,
        onUnlock: @escaping () -> Void
    ) {
        self.title = title
        self.duration = duration
        self.cost = cost
        self.overrideActive = overrideActive
        self.icon = icon()
        self.onUnlock = onUnlock
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                icon
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if !overrideActive {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.lockedIndigo)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color(uiColor: .secondarySystemGroupedBackground), lineWidth: 2))
                        .offset(x: 4, y: 4)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                if let duration {
                    Text(duration)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if overrideActive {
                    Text("Open until the seal repairs")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.hazardYellow)
                } else {
                    Label("\(cost) keys", systemImage: "key.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.lockedAmber)
                        .labelStyle(.titleAndIcon)
                }
            }

            Spacer(minLength: 8)

            if overrideActive {
                Text("Open")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.hazardYellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.hazardYellow.opacity(0.15))
                    .clipShape(Capsule())
            } else {
                Button(action: onUnlock) {
                    Text("Use keys")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(LockedTheme.keysGradient)
                        .foregroundStyle(Color(red: 0.22, green: 0.12, blue: 0.04))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(LockedCardBackground(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.lockedIndigo.opacity(overrideActive ? 0.08 : 0.16), lineWidth: 1)
        )
    }
}

// MARK: - Upcoming

private struct UpcomingSection: View {
    let items: [(course: Course, assignment: Assignment)]
    @Binding var courses: [Course]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LockedSectionLabel(title: "Up next", icon: "calendar")

            VStack(spacing: 8) {
                ForEach(items, id: \.assignment.id) { item in
                    NavigationLink {
                        CourseDetailView(courses: $courses, courseID: item.course.id)
                    } label: {
                        UpcomingRow(course: item.course, assignment: item.assignment)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct UpcomingRow: View {
    let course: Course
    let assignment: Assignment

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(courseAccent(course.name))
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(course.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(assignment.dueDate.formatted(.relative(presentation: .named)))
                .font(.caption.weight(.semibold))
                .foregroundStyle(assignment.isOverdue ? Color.lockedRose : .secondary)
        }
        .padding(14)
        .background(LockedCardBackground(cornerRadius: 16))
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
                        .fill(
                            LinearGradient(
                                colors: [Color.lockedIndigo.opacity(0.7), Color.lockedViolet],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
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

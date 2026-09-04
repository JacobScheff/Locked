import SwiftUI
import UIKit
import WidgetKit

struct MainPage: View {
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("screentime", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var screentime: Int = 0
    var days: Int { screentime / 86400 }
    var hours: Int { (screentime % 86400) / 3600 }
    var minutes: Int { (screentime % 3600) / 60 }

    @AppStorage("appCounts", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var appCounts: [String: Int] = [:]

    @AppStorage("keys", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var keys: Double = 0.0

    @AppStorage("karma", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var karma: Double = 0.0

    @AppStorage("lockedApps", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var lockedApps: [String] = []

    @AppStorage("courses", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var courses: [Course] = []

    @AppStorage("emergencyOverrideUntil", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var emergencyOverrideUntil: Double = 0

    @State private var showingBreakGlass = false
    @State private var now = Date()

    private var overrideActive: Bool {
        Date(timeIntervalSince1970: emergencyOverrideUntil) > now
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

                if screenTime.needsSetup {
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

                if !overrideActive {
                    EmergencySealCard {
                        showingBreakGlass = true
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(LockedBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: overrideActive ? "lock.open.fill" : "lock.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(overrideActive ? Color.hazardYellow : Color.lockedIndigo)
                    Text("Locked")
                        .font(.headline.weight(.bold))
                }
            }
        }
        .fullScreenCover(isPresented: $showingBreakGlass) {
            BreakGlassView {
                now = Date()
                updateWidget()
            }
        }
        .background {
            if screenTime.isAuthorized {
                UsageReportHost(selection: screenTime.selection)
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            now = Date()
            refreshScreenTime()
        }
    }

    private var visibleAppCounts: [String: Int] {
        ExcludedApps.strippingExcluded(appCounts)
    }

    private func refreshScreenTime() {
        screenTime.refreshStatus()
        applyUsageSnapshot()
        ScreenTimeShields.sync()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            applyUsageSnapshot()
        }
    }

    private func applyUsageSnapshot() {
        if UsageStore.hasSnapshot {
            appCounts = UsageStore.loadAppCounts().filter { UsageStore.isStillInstalled(name: $0.key) }
            lockedApps = UsageStore.loadLockedApps().filter { UsageStore.isStillInstalled(name: $0) }
        } else {
            appCounts = ExcludedApps.strippingExcluded(appCounts).filter { UsageStore.isStillInstalled(name: $0.key) }
            lockedApps = ExcludedApps.strippingExcluded(lockedApps).filter { UsageStore.isStillInstalled(name: $0) }
        }
        screentime = appCounts.values.reduce(0, +)
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
        .padding(.top, 8)
    }

    func updateWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
    }
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
    @State private var unlockCost: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LockedSectionLabel(
                title: overrideActive ? "Temporarily released" : "Locked apps",
                icon: overrideActive ? "lock.open.fill" : "lock.fill"
            )

            if visibleLockedApps.isEmpty {
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
                VStack(spacing: 10) {
                    ForEach(visibleLockedApps, id: \.self) { name in
                        HStack(spacing: 12) {
                            ManagedAppIcon(name: name, size: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(.body.weight(.semibold))
                                Text(formatAppDuration(appCounts[name] ?? 0))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(overrideActive ? "Accessible until the seal repairs" : "\(calculateUnlockCost(for: name)) keys to unlock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if overrideActive {
                                Text("Open")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.hazardYellow)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.hazardYellow.opacity(0.15))
                                    .clipShape(Capsule())
                            } else {
                                Button {
                                    appToUnlock = name
                                    unlockCost = calculateUnlockCost(for: name)
                                    showUnlockAlert = true
                                } label: {
                                    Text("Unlock")
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(LockedTheme.keysGradient)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                        .background(LockedCardBackground(cornerRadius: 18))
                    }
                }
            }
        }
        .alert("Unlock App", isPresented: $showUnlockAlert, presenting: appToUnlock) { app in
            if keys >= Double(unlockCost) {
                Button("Unlock (\(unlockCost) Keys)") {
                    keys -= Double(unlockCost)
                    lockedApps.removeAll { $0 == app }
                    ScreenTimeShields.sync()
                    updateWidget()
                }
                Button("Cancel", role: .cancel) { }
            } else {
                Button("OK", role: .cancel) { }
            }
        } message: { app in
            if keys >= Double(unlockCost) {
                Text("Unlocking \(app) will cost \(unlockCost) keys.")
            } else {
                Text("Unlocking \(app) needs \(unlockCost) keys, but you only have \(Int(keys)). Finish assignments to earn more.")
            }
        }
    }

    private var visibleLockedApps: [String] {
        ExcludedApps.strippingExcluded(lockedApps).sorted { lhs, rhs in
            let left = appCounts[lhs] ?? 0
            let right = appCounts[rhs] ?? 0
            return left == right ? lhs < rhs : left > right
        }
    }

    private var visibleAppCounts: [String: Int] {
        ExcludedApps.strippingExcluded(appCounts)
    }

    private func calculateUnlockCost(for app: String) -> Int {
        let totalUsage = Double(visibleAppCounts.values.reduce(0, +))
        let appUsage = Double(visibleAppCounts[app] ?? 0)
        let usagePercentage = totalUsage > 0 ? (appUsage / totalUsage) * 100.0 : 0.0
        let cost = pow(Double(lockedApps.count), 1.5) + 0.5 * pow(usagePercentage, 1.25) + 10.0
        return Int(cost.rounded())
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

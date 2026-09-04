import SwiftUI
import WidgetKit
import UIKit
import FamilyControls
import ManagedSettings

struct MainPage: View {
    @AppStorage("screentime", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var screentime: Int = 0
    var days: Int { screentime / 86400 }
    var hours: Int { (screentime % 86400) / 3600 }
    var minutes: Int { (screentime % 3600) / 60 }

    @AppStorage("appCounts", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var appCounts: [String: Int] = [:]

    @AppStorage("appOrder", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var appOrder: [String] = []

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
    @State private var showManagedApps = false
    @ObservedObject private var screenTime = ScreenTimeLockManager.shared

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
                            screenTime.applyShields()
                            updateWidget()
                        },
                        onExpired: {
                            now = Date()
                            screenTime.applyShields()
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
                    appCount: max(
                        appCounts.filter { $0.key != "Locked" }.count,
                        screenTime.managedItemCount
                    )
                )

                ScreenTimeSetupCard(manager: screenTime, showManagedApps: $showManagedApps)

                if appCounts.isEmpty {
                    SetupPromptCard()
                }

                LockedAppsSection(
                    lockedApps: $lockedApps,
                    keys: $keys,
                    appCounts: $appCounts,
                    overrideActive: overrideActive,
                    updateWidget: updateWidget,
                    screenTime: screenTime
                )

                if !upcomingItems.isEmpty {
                    UpcomingSection(items: Array(upcomingItems.prefix(3)), courses: $courses)
                }

                AppCountsCard(
                    appCounts: $appCounts,
                    appOrder: $appOrder,
                    keys: $keys,
                    lockedApps: $lockedApps,
                    overrideActive: overrideActive,
                    updateWidget: updateWidget
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
        .navigationDestination(isPresented: $showManagedApps) {
            ManagedAppsPage(manager: screenTime)
        }
        .onAppear {
            now = Date()
            screenTime.bootstrap()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            now = Date()
            screenTime.bootstrap()
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

private struct SetupPromptCard: View {
    var body: some View {
        NavigationLink {
            HowToUseView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(LockedTheme.karmaGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Finish setup")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Optional: connect Shortcuts to track usage. Screen Time is what actually blocks apps.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(LockedCardBackground())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Locked apps

struct LockedAppsSection: View {
    @Binding var lockedApps: [String]
    @Binding var keys: Double
    @Binding var appCounts: [String: Int]
    var overrideActive: Bool
    var updateWidget: () -> Void
    @ObservedObject var screenTime: ScreenTimeLockManager

    @State private var showUnlockAlert = false
    @State private var unlockTarget: UnlockTarget?

    private enum UnlockTarget: Identifiable {
        case named(String)
        case application(ApplicationToken, String)
        case category(ActivityCategoryToken)
        case webDomain(WebDomainToken)

        var id: String {
            switch self {
            case .named(let name): return "name:\(name)"
            case .application(let token, _): return "app:" + ScreenTimeCoding.id(for: token)
            case .category(let token): return "cat:" + ScreenTimeCoding.id(for: token)
            case .webDomain(let token): return "web:" + ScreenTimeCoding.id(for: token)
            }
        }

        var displayName: String {
            switch self {
            case .named(let name), .application(_, let name): return name
            case .category: return "this category"
            case .webDomain: return "this website"
            }
        }
    }

    private var hasScreenTimeLocks: Bool { !screenTime.lockedItems.isEmpty }
    private var showsEmpty: Bool { lockedApps.isEmpty && !hasScreenTimeLocks }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LockedSectionLabel(
                title: overrideActive ? "Temporarily released" : "Locked apps",
                icon: overrideActive ? "lock.open.fill" : "lock.fill"
            )

            if showsEmpty {
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
            } else if hasScreenTimeLocks {
                VStack(spacing: 10) {
                    ForEach(Array(screenTime.lockedItems.applications).sorted(by: tokenSort), id: \.self) { token in
                        let name = screenTime.displayName(for: token) ?? "App"
                        lockRow(costName: name) {
                            Label(token).labelStyle(.titleAndIcon)
                        } unlock: {
                            presentUnlock(.application(token, name))
                        }
                    }
                    ForEach(Array(screenTime.lockedItems.categories).sorted(by: tokenSort), id: \.self) { token in
                        lockRow(costName: "Category") {
                            Label(token).labelStyle(.titleAndIcon)
                        } unlock: {
                            presentUnlock(.category(token))
                        }
                    }
                    ForEach(Array(screenTime.lockedItems.webDomains).sorted(by: tokenSort), id: \.self) { token in
                        lockRow(costName: "Website") {
                            Label(token).labelStyle(.titleAndIcon)
                        } unlock: {
                            presentUnlock(.webDomain(token))
                        }
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(lockedApps, id: \.self) { name in
                        lockRow(costName: name) {
                            HStack(spacing: 12) {
                                AppIconView(appName: name)
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                Text(name)
                                    .font(.body.weight(.semibold))
                            }
                        } unlock: {
                            presentUnlock(.named(name))
                        }
                    }
                }
            }
        }
        .alert("Unlock App", isPresented: $showUnlockAlert, presenting: unlockTarget) { target in
            let cost = calculateUnlockCost(for: target.displayName)
            if keys >= Double(cost) {
                Button("Unlock (\(cost) Keys)") {
                    keys -= Double(cost)
                    performUnlock(target)
                    updateWidget()
                }
                Button("Cancel", role: .cancel) { }
            } else {
                Button("OK", role: .cancel) { }
            }
        } message: { target in
            let cost = calculateUnlockCost(for: target.displayName)
            if keys >= Double(cost) {
                Text("Unlocking \(target.displayName) will cost \(cost) keys.")
            } else {
                Text("Unlocking \(target.displayName) needs \(cost) keys, but you only have \(Int(keys)). Finish assignments to earn more.")
            }
        }
    }

    private func lockRow<Title: View>(
        costName: String,
        @ViewBuilder title: () -> Title,
        unlock: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            title()
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if overrideActive {
                    Text("Open")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.hazardYellow)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.hazardYellow.opacity(0.15))
                        .clipShape(Capsule())
                } else {
                    Button(action: unlock) {
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
                Text(overrideActive ? "Accessible until the seal repairs" : "\(calculateUnlockCost(for: costName)) keys to unlock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(LockedCardBackground(cornerRadius: 18))
    }

    private func presentUnlock(_ target: UnlockTarget) {
        unlockTarget = target
        showUnlockAlert = true
    }

    private func performUnlock(_ target: UnlockTarget) {
        switch target {
        case .named(let name):
            lockedApps.removeAll { $0 == name }
            screenTime.unlock(name: name)
        case .application(let token, _):
            screenTime.unlockApplication(token)
        case .category(let token):
            screenTime.unlockCategory(token)
        case .webDomain(let token):
            screenTime.unlockWebDomain(token)
        }
    }

    private func calculateUnlockCost(for app: String) -> Int {
        let totalUsage = Double(appCounts.values.reduce(0, +))
        let appUsage = Double(appCounts[app] ?? 0)
        let usagePercentage = totalUsage > 0 ? (appUsage / totalUsage) * 100.0 : 0.0
        let lockCount = max(lockedApps.count, screenTime.lockedItems.count)
        let cost = pow(Double(max(lockCount, 1)), 1.5) + 0.5 * pow(usagePercentage, 1.25) + 10.0
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
    @Binding var appOrder: [String]
    @Binding var keys: Double
    @Binding var lockedApps: [String]
    var overrideActive: Bool = false
    var updateWidget: () -> Void

    var totalAppCounts: Double { Double(appCounts.values.reduce(0, +)) }

    @State private var isEditing = false
    @State private var draftOrder: [String] = []
    @State private var draggedItem: String? = nil

    var activeOrder: [String] {
        var current = appOrder.filter { appCounts.keys.contains($0) }
        let missing = appCounts.keys.filter { !current.contains($0) }
        let sortedMissing = missing.sorted { (appCounts[$0] ?? 0) > (appCounts[$1] ?? 0) }
        current.append(contentsOf: sortedMissing)
        return current
    }

    var displayOrder: [String] {
        isEditing ? draftOrder : activeOrder
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LockedSectionLabel(
                title: isEditing ? "Edit ranking" : "App usage",
                icon: "chart.bar.fill"
            ) {
                editButton
            }

            VStack(alignment: .leading, spacing: 0) {
                if isEditing {
                    editActions
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }

                if appCounts.isEmpty {
                    Text("No apps recorded yet. Set up Shortcuts in the Guide tab.")
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

                                    AppIconView(appName: name)
                                        .frame(width: 32, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    Text(name)
                                        .font(.system(.body, design: .rounded, weight: .medium))
                                        .lineLimit(1)

                                    Spacer()

                                    if isEditing {
                                        reorderHandle(for: name)
                                    } else if isLocked {
                                        Label(overrideActive ? "Released" : "Locked", systemImage: overrideActive ? "lock.open.fill" : "lock.fill")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(overrideActive ? Color.hazardYellow : Color.secondary)
                                            .labelStyle(.titleAndIcon)
                                    } else {
                                        let count = Double(appCounts[name] ?? 0)
                                        let percentage = totalAppCounts > 0 ? count / totalAppCounts : 0
                                        AppUsageBar(percentage: percentage)
                                            .frame(width: 108)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 54)
                                .opacity(draggedItem == name ? 0.45 : 1.0)

                                if name != displayOrder.last {
                                    Divider().padding(.leading, 70)
                                }
                            }
                            .zIndex(draggedItem == name ? 1 : 0)
                        }
                    }
                    .padding(.vertical, 6)
                    .coordinateSpace(.named("ListArea"))
                }
            }
            .background(LockedCardBackground())
        }
    }

    @ViewBuilder
    private var editButton: some View {
        if !isEditing && !appCounts.isEmpty {
            Button {
                draftOrder = activeOrder
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isEditing = true
                }
            } label: {
                Text("Reorder")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.lockedIndigo.opacity(0.12))
                    .foregroundStyle(Color.lockedIndigo)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var editActions: some View {
        HStack(spacing: 8) {
            Button(role: .destructive) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isEditing = false
                }
            } label: {
                Text("Discard").font(.caption.bold()).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    draftOrder = draftOrder.sorted { a, b in
                        let countA = appCounts[a] ?? 0
                        let countB = appCounts[b] ?? 0
                        return countA == countB ? a < b : countA > countB
                    }
                }
            } label: {
                Text("Default").font(.caption.bold()).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)

            Button {
                appOrder = draftOrder
                updateWidget()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isEditing = false
                }
            } label: {
                Text("Save").font(.caption.bold()).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.lockedTeal)
        }
    }

    private func reorderHandle(for name: String) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.title3)
            .foregroundStyle(.secondary)
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named("ListArea"))
                    .onChanged { value in
                        if draggedItem == nil { draggedItem = name }
                        let rowHeight: CGFloat = 55
                        let clampedIndex = max(0, min(draftOrder.count - 1, Int(value.location.y / rowHeight)))
                        if let currentIdx = draftOrder.firstIndex(of: name), currentIdx != clampedIndex {
                            withAnimation(.spring(response: 0.3)) {
                                draftOrder.move(
                                    fromOffsets: IndexSet(integer: currentIdx),
                                    toOffset: clampedIndex > currentIdx ? clampedIndex + 1 : clampedIndex
                                )
                            }
                        }
                    }
                    .onEnded { _ in draggedItem = nil }
            )
    }
}

struct AppUsageBar: View {
    let percentage: Double

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
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

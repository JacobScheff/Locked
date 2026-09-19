import Combine
import SwiftUI
import WidgetKit

@MainActor
final class UsagePrefetch: ObservableObject {
    static let shared = UsagePrefetch()

    @Published private(set) var isReady = false
    @Published private(set) var shouldMount = false

    private var didSchedule = false

    /// Starts after Home has settled so Settings and the first paint stay light.
    func schedule(after delay: Duration = .milliseconds(900)) {
        guard !didSchedule else { return }
        didSchedule = true
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            await Task.yield()
            start()
        }
    }

    func start() {
        if !shouldMount {
            shouldMount = true
        }
    }

    func markReady() {
        if !isReady {
            isReady = true
        }
    }
}

/// Hidden host that warms FamilyControls labels for App usage.
/// Keep this off Settings so the hub push stays instant.
struct UsagePrefetchHost: View {
    @ObservedObject private var prefetch = UsagePrefetch.shared

    @AppStorage("appCounts", store: .lockedGroup)
    var appCounts: [String: Int] = [:]

    @AppStorage("lockedApps", store: .lockedGroup)
    var lockedApps: [String] = []

    @AppStorage("emergencyOverrideUntil", store: .lockedGroup)
    var emergencyOverrideUntil: Double = 0

    @State private var now = Date()

    private var overrideActive: Bool {
        Date(timeIntervalSince1970: emergencyOverrideUntil) > now
    }

    var body: some View {
        Group {
            if prefetch.shouldMount {
                AppCountsCard(
                    appCounts: $appCounts,
                    lockedApps: $lockedApps,
                    overrideActive: overrideActive
                )
                .frame(width: 320)
                .opacity(0.001)
                .offset(x: -1200)
                .onAppear {
                    Task { @MainActor in
                        // The card is on screen, but remote app icons still
                        // need a beat to resolve before we treat it as ready.
                        try? await Task.sleep(for: .milliseconds(350))
                        prefetch.markReady()
                    }
                }
            }
        }
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct SettingsPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                destinations
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(LockedBackground())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }

    private var destinations: some View {
        VStack(spacing: 0) {
            SettingsDestinationLink(
                title: "Guide",
                detail: "How Keys, Karma, and weekly lock work",
                icon: "questionmark.circle.fill",
                tint: .lockedIndigo,
                showDivider: true
            ) {
                HowToUseView()
            }

            SettingsDestinationLink(
                title: "Archive",
                detail: "View or delete hidden classes and work",
                icon: "archivebox.fill",
                tint: .lockedViolet,
                showDivider: true
            ) {
                ArchiveSettingsView()
            }

            SettingsDestinationLink(
                title: "App usage",
                detail: "Time spent in the apps Locked manages",
                icon: "chart.bar.fill",
                tint: .lockedTeal,
                showDivider: true
            ) {
                UsageSettingsView()
            }

            SettingsDestinationLink(
                title: "Emergency",
                detail: "Break the glass, then open the vault",
                icon: "light.beacon.max.fill",
                tint: .hazardRed,
                showDivider: false
            ) {
                EmergencySettingsView()
            }
        }
        .background(LockedCardBackground(cornerRadius: 22))
    }
}

private struct SettingsDestinationLink<Destination: View>: View {
    let title: String
    let detail: String
    let icon: String
    let tint: Color
    let showDivider: Bool
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(tint)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())

                if showDivider {
                    Divider()
                        .padding(.leading, 66)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct ArchiveSettingsView: View {
    @AppStorage("courses", store: .lockedGroup)
    var courses: [Course] = []

    @AppStorage("keys", store: .lockedGroup) var keys: Double = 0.0
    @AppStorage("karma", store: .lockedGroup) var karma: Double = 0.0

    var body: some View {
        HiddenWorkView(courses: $courses, keys: $keys, karma: $karma)
    }
}

struct UsageSettingsView: View {
    @EnvironmentObject private var screenTime: ScreenTimeManager
    @ObservedObject private var prefetch = UsagePrefetch.shared

    @AppStorage("appCounts", store: .lockedGroup)
    var appCounts: [String: Int] = [:]

    @AppStorage("lockedApps", store: .lockedGroup)
    var lockedApps: [String] = []

    @AppStorage("emergencyOverrideUntil", store: .lockedGroup)
    var emergencyOverrideUntil: Double = 0

    @State private var now = Date()
    @State private var loadTimedOut = false

    private var overrideActive: Bool {
        Date(timeIntervalSince1970: emergencyOverrideUntil) > now
    }

    /// Keep the launch spinner up until this session's usage snapshot is in
    /// and FamilyControls labels have been warmed — not just until the
    /// hidden prefetch card appears.
    private var showsLoadingCover: Bool {
        if loadTimedOut { return false }
        guard screenTime.shouldCollectUsage else { return false }
        if !screenTime.hasLoadedUsageThisSession { return true }
        return !prefetch.isReady
    }

    var body: some View {
        ZStack {
            if !showsLoadingCover {
                ScrollView {
                    AppCountsCard(
                        appCounts: $appCounts,
                        lockedApps: $lockedApps,
                        overrideActive: overrideActive
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
            }

            if showsLoadingCover {
                LockedLaunchOverlay()
                    .transition(.opacity)
            }
        }
        .background(LockedBackground())
        .navigationTitle("App usage")
        .navigationBarTitleDisplayMode(.large)
        .animation(.easeOut(duration: 0.28), value: showsLoadingCover)
        .onAppear {
            now = Date()
            prefetch.start()
        }
        .task(id: showsLoadingCover) {
            guard showsLoadingCover else { return }
            try? await Task.sleep(for: .seconds(12))
            loadTimedOut = true
        }
    }
}

struct EmergencySettingsView: View {
    @EnvironmentObject private var screenTime: ScreenTimeManager

    @AppStorage("emergencyOverrideUntil", store: .lockedGroup)
    var emergencyOverrideUntil: Double = 0

    @AppStorage("innerVaultUnlockedUntil", store: .lockedGroup)
    var innerVaultUnlockedUntil: Double = 0

    @State private var presentedRitual: EmergencyRitual?
    @State private var now = Date()

    private var overrideActive: Bool {
        Date(timeIntervalSince1970: emergencyOverrideUntil) > now
    }

    private var vaultUnlocked: Bool {
        overrideActive && innerVaultUnlockedUntil > 0 && abs(innerVaultUnlockedUntil - emergencyOverrideUntil) < 0.5
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last resort only")
                        .font(.lockedTitle(26))
                    Text("Break the glass if you truly cannot wait. Locks lift for one hour, then return on their own. While the seal is broken, you can open the inner vault.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)

                if overrideActive {
                    OverrideStatusBanner(
                        onRestore: {
                            now = Date()
                            reloadWidget()
                        },
                        onExpired: {
                            now = Date()
                            ScreenTimeShields.sync()
                            reloadWidget()
                        }
                    )

                    VaultSealCard(unlocked: vaultUnlocked) {
                        presentedRitual = .vault
                    }
                } else {
                    EmergencySealCard {
                        presentedRitual = .glass
                    }
                }

                weeklyLockSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(LockedBackground())
        .navigationTitle("Emergency")
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(item: $presentedRitual) { ritual in
            switch ritual {
            case .glass:
                BreakGlassView {
                    now = Date()
                    reloadWidget()
                }
            case .vault:
                InnerVaultView {
                    reloadWidget()
                }
            }
        }
        .onAppear { now = Date() }
    }

    private var weeklyLockSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LockedSectionLabel(title: "Weekly lock", icon: "lock.rotation")
            Button {
                screenTime.simulateWeeklyLock()
                reloadWidget()
            } label: {
                Label("Refresh weekly lock now", systemImage: "lock.rotation")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.lockedRose)
            Text("Applies this week’s lock immediately and refreshes usage so remaining names get their shields.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func reloadWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
    }
}

private enum EmergencyRitual: String, Identifiable {
    case glass
    case vault

    var id: String { rawValue }
}

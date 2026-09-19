import Combine
import SwiftUI
import WidgetKit

@MainActor
final class UsagePrefetch: ObservableObject {
    static let shared = UsagePrefetch()

    @Published private(set) var isReady = false
    @Published private(set) var shouldMount = false

    private var isWaitingToMarkReady = false
    private var didScheduleFromSettings = false
    private var didOpenUsagePage = false

    /// Cheap data check after the hub push, then a delayed off-screen warm
    /// only if the user stays on Settings. Mounting FamilyControls views
    /// immediately would freeze the next tap.
    func startAfterSettingsPresented() {
        guard !isReady, !didScheduleFromSettings else { return }
        didScheduleFromSettings = true
        Task { @MainActor in
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(400))
            if !ScreenTimeManager.shared.shouldCollectUsage {
                markReady()
                return
            }
            try? await Task.sleep(for: .seconds(2))
            guard !isReady, !didOpenUsagePage else { return }
            start()
        }
    }

    func noteUsagePageOpened() {
        didOpenUsagePage = true
    }

    func start() {
        if !ScreenTimeManager.shared.shouldCollectUsage {
            markReady()
            return
        }
        if !shouldMount {
            shouldMount = true
        }
    }

    func noteHostAppeared() {
        guard !isReady, !isWaitingToMarkReady else { return }
        isWaitingToMarkReady = true
        Task { @MainActor in
            await waitUntilLoaded()
            markReady()
        }
    }

    func markReady() {
        if !isReady {
            isReady = true
        }
    }

    private func waitUntilLoaded() async {
        let deadline = Date().addingTimeInterval(8)
        while ScreenTimeManager.shared.shouldCollectUsage
                && !UsageStore.hasSnapshot
                && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(120))
        }
        await Task.yield()
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
        Color.clear
            .frame(width: 0, height: 0)
            .background(alignment: .topLeading) {
                if prefetch.shouldMount {
                    AppCountsCard(
                        appCounts: $appCounts,
                        lockedApps: $lockedApps,
                        overrideActive: overrideActive
                    )
                    .frame(width: 360)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(0.01)
                    .offset(x: -2400)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .onAppear {
                        prefetch.noteHostAppeared()
                    }
                }
            }
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
        .navigationDestination(for: SettingsDestination.self) { destination in
            switch destination {
            case .guide:
                HowToUseView()
            case .archive:
                ArchiveSettingsView()
            case .usage:
                UsageSettingsView()
            case .emergency:
                EmergencySettingsView()
            }
        }
        .onAppear {
            UsagePrefetch.shared.startAfterSettingsPresented()
        }
    }

    private var destinations: some View {
        VStack(spacing: 0) {
            SettingsDestinationLink(
                title: "Guide",
                detail: "How Keys, Karma, and weekly lock work",
                icon: "questionmark.circle.fill",
                tint: .lockedIndigo,
                destination: .guide,
                showDivider: true
            )

            SettingsDestinationLink(
                title: "Archive",
                detail: "View or delete hidden classes and work",
                icon: "archivebox.fill",
                tint: .lockedViolet,
                destination: .archive,
                showDivider: true
            )

            SettingsDestinationLink(
                title: "App usage",
                detail: "Time spent in the apps Locked manages",
                icon: "chart.bar.fill",
                tint: .lockedTeal,
                destination: .usage,
                showDivider: true
            )

            SettingsDestinationLink(
                title: "Emergency",
                detail: "Break the glass, then open the vault",
                icon: "light.beacon.max.fill",
                tint: .hazardRed,
                destination: .emergency,
                showDivider: false
            )
        }
        .background(LockedCardBackground(cornerRadius: 22))
    }
}

private enum SettingsDestination: Hashable {
    case guide, archive, usage, emergency
}

private struct SettingsDestinationLink: View {
    let title: String
    let detail: String
    let icon: String
    let tint: Color
    let destination: SettingsDestination
    let showDivider: Bool

    var body: some View {
        NavigationLink(value: destination) {
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
    @ObservedObject private var prefetch = UsagePrefetch.shared

    @AppStorage("appCounts", store: .lockedGroup)
    var appCounts: [String: Int] = [:]

    @AppStorage("lockedApps", store: .lockedGroup)
    var lockedApps: [String] = []

    @AppStorage("emergencyOverrideUntil", store: .lockedGroup)
    var emergencyOverrideUntil: Double = 0

    @State private var now = Date()
    @State private var canMountCard = false
    @State private var showList = false

    private var overrideActive: Bool {
        Date(timeIntervalSince1970: emergencyOverrideUntil) > now
    }

    var body: some View {
        ZStack {
            if canMountCard {
                ScrollView {
                    AppCountsCard(
                        appCounts: $appCounts,
                        lockedApps: $lockedApps,
                        overrideActive: overrideActive
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                    .onAppear {
                        prefetch.noteHostAppeared()
                        if prefetch.isReady {
                            showList = true
                        }
                    }
                }
                .opacity(showList ? 1 : 0)
                .allowsHitTesting(showList)
            }

            if !showList {
                LockedLaunchSpinner()
                    .frame(width: 118, height: 118)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LockedBackground())
        .navigationTitle("App usage")
        .navigationBarTitleDisplayMode(.large)
        .animation(.easeOut(duration: 0.28), value: showList)
        .onChange(of: prefetch.isReady) { _, ready in
            if ready, canMountCard {
                showList = true
            }
        }
        .onAppear {
            now = Date()
            prefetch.noteUsagePageOpened()
            // Keep this destination light so the push is instant. Build the
            // FamilyControls list only after the page is on screen.
            Task { @MainActor in
                await Task.yield()
                try? await Task.sleep(for: .milliseconds(350))
                if !ScreenTimeManager.shared.shouldCollectUsage {
                    prefetch.markReady()
                    showList = true
                }
                canMountCard = true
            }
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

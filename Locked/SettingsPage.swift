import SwiftUI
import WidgetKit

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
    @AppStorage("appCounts", store: .lockedGroup)
    var appCounts: [String: Int] = [:]

    @AppStorage("lockedApps", store: .lockedGroup)
    var lockedApps: [String] = []

    @AppStorage("emergencyOverrideUntil", store: .lockedGroup)
    var emergencyOverrideUntil: Double = 0

    @State private var now = Date()
    @State private var showUsage = false

    private var overrideActive: Bool {
        Date(timeIntervalSince1970: emergencyOverrideUntil) > now
    }

    var body: some View {
        Group {
            if showUsage {
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
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading usage")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(LockedBackground())
        .navigationTitle("App usage")
        .navigationBarTitleDisplayMode(.large)
        .task {
            now = Date()
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(160))
            showUsage = true
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

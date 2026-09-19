import SwiftUI
import WidgetKit

struct SettingsPage: View {
    @EnvironmentObject private var screenTime: ScreenTimeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                destinations
                developerSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(LockedBackground())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LockedTheme.karmaGradient)
                Image(systemName: "gearshape.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            .shadow(color: Color.lockedIndigo.opacity(0.28), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Make Locked yours")
                    .font(.headline.weight(.bold))
                Text("Guide, archive, usage, and emergency each open their own page.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LockedCardBackground(cornerRadius: 20))
        .padding(.top, 4)
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

    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LockedSectionLabel(title: "Developer", icon: "hammer.fill")
            Button {
                screenTime.simulateWeeklyLock()
                WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
            } label: {
                Label("Simulate weekly lock", systemImage: "lock.rotation")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.lockedRose)
            Text("Locks at least one managed app using Screen Time tokens, then refreshes usage so remaining names get their shields.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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

    private var overrideActive: Bool {
        Date(timeIntervalSince1970: emergencyOverrideUntil) > now
    }

    var body: some View {
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
        .background(LockedBackground())
        .navigationTitle("App usage")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { now = Date() }
    }
}

struct EmergencySettingsView: View {
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

    private func reloadWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
    }
}

private enum EmergencyRitual: String, Identifiable {
    case glass
    case vault

    var id: String { rawValue }
}

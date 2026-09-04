import FamilyControls
import ManagedSettings
import SwiftUI

struct ScreenTimeSetupCard: View {
    @ObservedObject var manager: ScreenTimeLockManager
    @Binding var showManagedApps: Bool

    var body: some View {
        Button {
            showManagedApps = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: statusIcon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(statusGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(statusDetail)
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

    private var statusIcon: String {
        if manager.isAuthorized && manager.hasManagedApps {
            return "checkmark.shield.fill"
        }
        if manager.isAuthorized {
            return "app.badge.checkmark"
        }
        return "hourglass"
    }

    private var statusGradient: LinearGradient {
        if manager.isAuthorized && manager.hasManagedApps {
            return LockedTheme.karmaGradient
        }
        return LinearGradient(
            colors: [Color.lockedAmber, Color.orange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var statusTitle: String {
        if manager.isAuthorized && manager.hasManagedApps {
            return "Screen Time is enforcing locks"
        }
        if manager.isAuthorized {
            return "Choose apps to lock"
        }
        return "Allow Screen Time access"
    }

    private var statusDetail: String {
        if manager.isAuthorized && manager.hasManagedApps {
            return "\(manager.managedItemCount) apps or categories can be shielded. Tap to change."
        }
        if manager.isAuthorized {
            return "Permission is on, but no apps are selected — so nothing can be blocked."
        }
        return "iOS will not block apps until Locked is allowed to use Screen Time."
    }
}

struct ManagedAppsPage: View {
    @ObservedObject var manager: ScreenTimeLockManager
    @State private var showPicker = false
    @State private var authError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                intro

                authorizationCard

                if manager.isAuthorized {
                    pickerCard
                    selectedAppsCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(LockedBackground())
        .navigationTitle("Screen Time")
        .navigationBarTitleDisplayMode(.large)
        .familyActivityPicker(isPresented: $showPicker, selection: $manager.selection)
        .onChange(of: manager.selection) { _, _ in
            manager.adoptNamedLocksIfNeeded()
            manager.applyShields()
        }
        .onAppear {
            manager.refreshAuthorizationStatus()
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This is what actually blocks apps.")
                .font(.lockedTitle(28))
            Text("Allowing Screen Time only grants permission. Locked then has to select apps and write a shield. Until both happen, iOS will still open them.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var authorizationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            LockedSectionLabel(title: "Permission", icon: "hourglass")

            LockedCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: manager.isAuthorized ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .font(.title2)
                            .foregroundStyle(manager.isAuthorized ? Color.lockedTeal : Color.lockedRose)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(manager.isAuthorized ? "Screen Time allowed" : "Screen Time not allowed")
                                .font(.headline)
                            Text(manager.isAuthorized
                                 ? "Locked can apply shields on this iPhone."
                                 : "Without this, Managed Settings cannot hide or block anything.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !manager.isAuthorized {
                        Button {
                            Task {
                                await manager.requestAuthorization()
                                if !manager.isAuthorized {
                                    authError = "Authorization was denied. Enable Locked under Settings → Screen Time → Apps with Screen Time Access."
                                }
                            }
                        } label: {
                            Text("Allow Screen Time")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(LockedTheme.karmaGradient)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if let authError {
                        Text(authError)
                            .font(.caption)
                            .foregroundStyle(Color.lockedRose)
                    }
                }
            }
        }
    }

    private var pickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            LockedSectionLabel(title: "Managed apps", icon: "square.grid.2x2.fill")

            LockedCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pick the apps and categories Locked is allowed to shield. Weekly locks only apply to this list. Anything already locked on Home is shielded as soon as it appears here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        showPicker = true
                    } label: {
                        Text(manager.hasManagedApps ? "Change selection" : "Choose apps")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(LockedTheme.karmaGradient)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var selectedAppsCard: some View {
        if manager.hasManagedApps {
            VStack(alignment: .leading, spacing: 12) {
                LockedSectionLabel(title: "Selected", icon: "app.badge.checkmark")

                VStack(spacing: 0) {
                    ForEach(Array(manager.selection.applicationTokens).sorted(by: tokenSort), id: \.self) { token in
                        managedRow {
                            Label(token)
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    ForEach(Array(manager.selection.categoryTokens).sorted(by: tokenSort), id: \.self) { token in
                        managedRow {
                            Label(token)
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    ForEach(Array(manager.selection.webDomainTokens).sorted(by: tokenSort), id: \.self) { token in
                        managedRow {
                            Label(token)
                                .labelStyle(.titleAndIcon)
                        }
                    }
                }
                .background(LockedCardBackground())
            }
        }
    }

    private func managedRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .frame(height: 52)
            Divider().padding(.leading, 16)
        }
    }
}

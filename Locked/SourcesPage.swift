import SwiftUI

struct SourcesPage: View {
    @Binding var courses: [Course]
    @Binding var keys: Double
    @Binding var karma: Double

    @EnvironmentObject private var sources: ExternalSourceController
    @State private var gradescopeLogin: GradescopeLoginDraft?
    @State private var brightspaceLogin: BrightspaceLoginDraft?
    @State private var errorMessage: String?
    @State private var disconnectProvider: ExternalSourceProvider?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                intro
                if sources.canRefresh {
                    refreshCard
                }
                VStack(alignment: .leading, spacing: 12) {
                    LockedSectionLabel(title: "Available", icon: "link")
                    SourceProviderCard(
                        provider: .gradescope,
                        state: sources.gradescope,
                        isRefreshing: sources.isRefreshing,
                        onConnect: { gradescopeLogin = GradescopeLoginDraft() },
                        onRefresh: { Task { await refresh(.gradescope) } },
                        onDisconnect: { disconnectProvider = .gradescope }
                    )
                    SourceProviderCard(
                        provider: .brightspace,
                        state: sources.brightspace,
                        isRefreshing: sources.isRefreshing,
                        onConnect: { brightspaceLogin = BrightspaceLoginDraft() },
                        onRefresh: { Task { await refresh(.brightspace) } },
                        onDisconnect: { disconnectProvider = .brightspace }
                    )
                }
                footnote
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(LockedBackground())
        .navigationTitle("Sources")
        .navigationBarTitleDisplayMode(.large)
        .lockedRefreshable {
            guard sources.canRefresh, !sources.isRefreshing else { return }
            await refreshAll()
        }
        .fullScreenCover(item: $gradescopeLogin) { _ in
            GradescopeSignInView(
                onConnect: { auth in
                    let result = try await sources.connectGradescope(
                        auth: auth,
                        courses: courses,
                        keys: keys,
                        karma: karma
                    )
                    apply(result)
                    gradescopeLogin = nil
                },
                onCancel: {
                    gradescopeLogin = nil
                }
            )
        }
        .sheet(item: $brightspaceLogin) { _ in
            BrightspaceConnectSheet(lastHost: sources.brightspace.host) { auth in
                let result = try await sources.connectBrightspace(
                    auth: auth,
                    courses: courses,
                    keys: keys,
                    karma: karma
                )
                withAnimation {
                    courses = result.courses
                    keys = result.keys
                    karma = result.karma
                }
            }
        }
        .alert("Couldn’t update", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            "Disconnect \(disconnectProvider?.title ?? "source")?",
            isPresented: Binding(
                get: { disconnectProvider != nil },
                set: { if !$0 { disconnectProvider = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                if disconnectProvider == .gradescope {
                    sources.disconnectGradescope()
                } else if disconnectProvider == .brightspace {
                    sources.disconnectBrightspace()
                }
                disconnectProvider = nil
            }
            Button("Cancel", role: .cancel) {
                disconnectProvider = nil
            }
        } message: {
            Text("Imported courses stay in Locked. Hide anything you don’t want counted; they just won’t update until you connect again.")
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bring your classes in")
                .font(.lockedTitle(26))
            Text("Connect a school site and Locked will load this term’s courses. Keys and Karma use the real submitted time — not whenever you refresh.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var refreshCard: some View {
        Button {
            Task { await refreshAll() }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 44, height: 44)
                    SpinningSyncIcon(
                        spinning: sources.isRefreshing,
                        color: .white,
                        font: .title3.weight(.bold)
                    )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(sources.isRefreshing ? "Updating assignments…" : "Refresh data")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(refreshSubtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LockedTheme.heroGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                    )
                    .shadow(color: Color.lockedIndigo.opacity(0.28), radius: 18, x: 0, y: 10)
            }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!sources.isRefreshing)
    }

    private var refreshSubtitle: String {
        if sources.isRefreshing { return "Updating assignments…" }
        let states = [sources.gradescope, sources.brightspace].filter(\.isConnected)
        if let latest = states.max(by: { ($0.lastSyncedAt ?? .distantPast) < ($1.lastSyncedAt ?? .distantPast) }) {
            if let summary = latest.lastSummary { return summary }
            if let date = latest.lastSyncedAt {
                return "Last updated \(date.formatted(.relative(presentation: .named)))"
            }
        }
        return "Pull the latest due dates and submissions"
    }

    private var footnote: some View {
        Text("Gradescope and Brightspace sign-in stay on this iPhone. They’re only sent to those school sites when you connect or refresh.")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    private func refreshAll() async {
        do {
            let result = try await sources.refreshConnectedSources(courses: courses, keys: keys, karma: karma)
            apply(result)
        } catch {
            if ExternalSourceController.isCancellation(error) { return }
            errorMessage = error.localizedDescription
        }
    }

    private func refresh(_ provider: ExternalSourceProvider) async {
        do {
            let result: (courses: [Course], keys: Double, karma: Double)
            switch provider {
            case .gradescope:
                result = try await sources.refreshGradescope(courses: courses, keys: keys, karma: karma)
            case .brightspace:
                result = try await sources.refreshBrightspace(courses: courses, keys: keys, karma: karma)
            }
            apply(result)
        } catch {
            if ExternalSourceController.isCancellation(error) { return }
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ result: (courses: [Course], keys: Double, karma: Double)) {
        withAnimation {
            courses = result.courses
            keys = result.keys
            karma = result.karma
        }
    }
}

private struct GradescopeLoginDraft: Identifiable {
    var id: String { "gradescope-login" }
}

private struct BrightspaceLoginDraft: Identifiable {
    var id: String { "brightspace-login" }
}

private struct SourceProviderCard: View {
    let provider: ExternalSourceProvider
    let state: SourceConnectionState
    let isRefreshing: Bool
    var onConnect: () -> Void
    var onRefresh: () -> Void
    var onDisconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(iconFill)
                    Image(systemName: provider.icon)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(provider.title)
                            .font(.title3.weight(.bold))
                        Spacer()
                        statusPill
                    }
                    Text(provider.blurb)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if provider.isAvailable, state.isConnected {
                connectedFacts
                HStack(spacing: 10) {
                    Button(action: onRefresh) {
                        HStack {
                            SpinningSyncIcon(
                                spinning: isRefreshing,
                                color: .white,
                                font: .subheadline.weight(.bold)
                            )
                            Text(isRefreshing ? "Refreshing" : "Refresh")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.lockedIndigo)
                    .allowsHitTesting(!isRefreshing)

                    Button(role: .destructive, action: onDisconnect) {
                        Text("Disconnect")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
            } else if provider.isAvailable {
                Button(action: onConnect) {
                    Label("Connect", systemImage: "link")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(LockedTheme.karmaGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Text("Placeholder — sync isn’t wired up yet.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(18)
        .background(LockedCardBackground())
        .opacity(provider.isAvailable ? 1 : 0.88)
    }

    private var iconFill: AnyGradient {
        switch provider {
        case .gradescope:
            return Color(red: 0.16, green: 0.38, blue: 0.78).gradient
        case .brightspace:
            return Color(red: 0.92, green: 0.45, blue: 0.18).gradient
        }
    }

    @ViewBuilder
    private var statusPill: some View {
        if !provider.isAvailable {
            LockedStatusPill(text: "Soon", color: .secondary)
        } else if state.isConnected {
            LockedStatusPill(text: "Connected", color: .lockedTeal, filled: true)
        } else {
            LockedStatusPill(text: "Not connected", color: .secondary)
        }
    }

    private var connectedFacts: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !state.email.isEmpty {
                labeledFact(icon: "envelope.fill", text: state.email)
            }
            if let host = state.host, !host.isEmpty {
                labeledFact(icon: "globe", text: host)
            }
            if let term = state.lastTermName, !term.isEmpty {
                labeledFact(icon: "calendar", text: term)
            }
            labeledFact(
                icon: "books.vertical.fill",
                text: "\(state.courseCount) course\(state.courseCount == 1 ? "" : "s") · \(state.assignmentCount) assignment\(state.assignmentCount == 1 ? "" : "s")"
            )
            if let date = state.lastSyncedAt {
                labeledFact(icon: "clock.fill", text: "Updated \(date.formatted(.relative(presentation: .named)))")
            }
            if let error = state.lastError {
                labeledFact(icon: "exclamationmark.triangle.fill", text: error, tint: .lockedRose)
            }
        }
        .padding(12)
        .background(Color.lockedIndigo.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func labeledFact(icon: String, text: String, tint: Color = .secondary) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 16)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint == .lockedRose ? Color.lockedRose : Color.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}



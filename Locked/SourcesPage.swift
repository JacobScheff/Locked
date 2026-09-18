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
        .refreshable {
            guard sources.canRefresh else { return }
            await refreshAll()
        }
        .sheet(item: $gradescopeLogin) { _ in
            GradescopeLoginSheet { email, password in
                let result = try await sources.connectGradescope(
                    email: email,
                    password: password,
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
        .sheet(item: $brightspaceLogin) { _ in
            BrightspaceConnectSheet { auth in
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
        Text("Passwords and Brightspace sign-in stay on this iPhone. They’re only sent to Gradescope or your school’s Brightspace when you connect or refresh.")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }

    private func refreshAll() async {
        do {
            let result = try await sources.refreshConnectedSources(courses: courses, keys: keys, karma: karma)
            apply(result)
        } catch {
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

    private var iconFill: LinearGradient {
        switch provider {
        case .gradescope:
            return LinearGradient(colors: [Color(red: 0.16, green: 0.38, blue: 0.78), .lockedIndigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .brightspace:
            return LinearGradient(colors: [Color(red: 0.92, green: 0.45, blue: 0.18), Color(red: 0.82, green: 0.28, blue: 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
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

struct GradescopeLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Field?

    let onConnect: (String, String) async throws -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    enum Field { case email, password }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sign in to Gradescope")
                            .font(.lockedTitle(24))
                        Text("Use the same email and password as gradescope.com. School SSO isn’t supported yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    field(title: "Email") {
                        TextField("you@university.edu", text: $email)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focused, equals: .email)
                    }

                    field(title: "Password") {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .focused($focused, equals: .password)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.lockedRose)
                    }

                    Button {
                        Task { await connect() }
                    } label: {
                        HStack {
                            if isWorking {
                                ProgressView().tint(.white)
                            }
                            Text(isWorking ? "Importing…" : "Sign in & import")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSubmit ? LockedTheme.karmaGradient : LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(!canSubmit || isWorking)

                    Text("Locked stores your password in the iPhone keychain and uses it only to refresh Gradescope.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(20)
            }
            .background(LockedBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isWorking)
                }
            }
            .onAppear { focused = .email }
        }
        .presentationDetents([.large])
        .tint(.lockedIndigo)
        .interactiveDismissDisabled(isWorking)
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .padding(16)
                .background(LockedCardBackground(cornerRadius: 16))
        }
    }

    private func connect() async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await onConnect(email, password)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct BrightspaceConnectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    let onConnect: (BrightspaceStoredAuth) async throws -> Void

    @State private var host = BrightspaceConfig.defaultHost
    @State private var showBrowser = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sign in to Brightspace")
                            .font(.lockedTitle(24))
                        Text("You’ll open your school’s Brightspace site and sign in the usual way. If you’re already signed in, Locked continues automatically.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    field(title: "School site") {
                        TextField("brightspace.usc.edu", text: $host)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focused)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.lockedRose)
                    }

                    Button {
                        do {
                            host = try BrightspaceParser.normalizedHost(host)
                            errorMessage = nil
                            showBrowser = true
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    } label: {
                        HStack {
                            if isWorking {
                                ProgressView().tint(.white)
                            }
                            Text(isWorking ? "Importing…" : "Open Brightspace")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSubmit ? LockedTheme.karmaGradient : LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(!canSubmit || isWorking)

                    Text("Locked keeps the Brightspace session on this iPhone and uses it only to refresh assignments.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(20)
            }
            .background(LockedBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isWorking)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.large])
        .tint(.lockedIndigo)
        .interactiveDismissDisabled(isWorking)
        .fullScreenCover(isPresented: $showBrowser) {
            BrightspaceSignInView(
                host: (try? BrightspaceParser.normalizedHost(host)) ?? host,
                onSignedIn: { auth in
                    showBrowser = false
                    Task { await finish(auth) }
                },
                onCancel: {
                    showBrowser = false
                }
            )
        }
    }

    private var canSubmit: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .padding(16)
                .background(LockedCardBackground(cornerRadius: 16))
        }
    }

    private func finish(_ auth: BrightspaceStoredAuth) async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await onConnect(auth)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

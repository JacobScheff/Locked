import SwiftUI
import WebKit

struct BrightspaceConnectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var lastHost: String? = nil
    let onConnect: (BrightspaceStoredAuth) async throws -> Void

    @State private var query = ""
    @State private var results: [BrightspaceInstitution] = []
    @State private var selected: BrightspaceInstitution?
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var showBrowser = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Find your Brightspace")
                            .font(.lockedTitle(24))
                        Text("Every school has its own Brightspace website. Search the name on your student email, or paste the address you already use in a browser.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    searchField

                    if let selected {
                        selectedCard(selected)
                    }

                    resultsSection

                    helpCard

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.lockedRose)
                    }

                    Button {
                        openSelectedSite()
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
                        .background(canSubmit ? LockedTheme.karmaGradient : Color.gray.gradient)
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
            .onAppear {
                focused = true
                if let lastHost, selected == nil {
                    selected = BrightspaceInstitution(name: lastHost, host: lastHost)
                }
            }
            .task(id: query) {
                await searchSchools()
            }
        }
        .presentationDetents([.large])
        .tint(.lockedIndigo)
        .interactiveDismissDisabled(isWorking)
        .fullScreenCover(isPresented: $showBrowser) {
            BrightspaceSignInView(
                host: resolvedHost ?? "",
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

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("School")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Purdue, York University, or a website", text: $query)
                    .textContentType(.organizationName)
                    .keyboardType(.default)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .submitLabel(.search)
                if isSearching {
                    ProgressView()
                } else if !query.isEmpty {
                    Button {
                        query = ""
                        selected = nil
                        results = []
                        searchError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear school search")
                }
            }
            .padding(16)
            .background(LockedCardBackground(cornerRadius: 16))

            Text("Type a school name. If you already know the site, paste yourschool.brightspace.com.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if let lastHost, query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recently used")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                institutionRow(
                    BrightspaceInstitution(name: lastHost, host: lastHost),
                    subtitle: "Continue with this website"
                )
            }
        } else if let searchError, results.isEmpty {
            Text(searchError)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.lockedRose)
        } else if showEmptyResults {
            Text("No schools matched. Paste the Brightspace website from Safari’s address bar — it often looks like yourschool.brightspace.com.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if !results.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(queryLooksLikeWebsite ? "Matching websites" : "Matching schools")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(spacing: 8) {
                    ForEach(results) { institution in
                        institutionRow(institution)
                    }
                }
            }
        }
    }

    private var helpCard: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                helpRow(number: "1", text: "Search the school name from your email or student portal, not a city or a personal login.")
                helpRow(number: "2", text: "Or open Brightspace in Safari, copy the website from the address bar, and paste it above.")
                helpRow(number: "3", text: "Typical addresses look like yourschool.brightspace.com, brightspace.yourschool.edu, or learn.yourschool.edu.")
                Link(destination: BrightspaceInstitutionSearch.loginFinderURL) {
                    Label("D2L’s Brightspace login finder", systemImage: "arrow.up.right.square")
                        .font(.footnote.weight(.semibold))
                }
            }
            .padding(.top, 8)
        } label: {
            Text("How do I find my school?")
                .font(.subheadline.weight(.semibold))
        }
        .padding(14)
        .background(LockedCardBackground(cornerRadius: 16))
    }

    private func helpRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.lockedIndigo, in: Circle())
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func selectedCard(_ institution: BrightspaceInstitution) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(institution.isCustom ? "Using this website" : institution.name, systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.lockedTeal)
            Text(institution.host)
                .font(.footnote.weight(.semibold))
            Text("We’ll open \(institution.website) so you can sign in the usual way.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lockedTeal.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func institutionRow(_ institution: BrightspaceInstitution, subtitle: String? = nil) -> some View {
        let isSelected = selected?.host == institution.host && selected?.isCustom == institution.isCustom
        return Button {
            selected = institution
            errorMessage = nil
        } label: {
            HStack(spacing: 12) {
                Image(systemName: institution.isCustom ? "globe" : "building.columns.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.lockedIndigo)
                    .frame(width: 34, height: 34)
                    .background(
                        (isSelected ? Color.lockedIndigo : Color.lockedIndigo.opacity(0.12)),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(institution.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle ?? institution.host)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.lockedIndigo)
                }
            }
            .padding(12)
            .background(LockedCardBackground(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.lockedIndigo : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var showEmptyResults: Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && !isSearching && results.isEmpty && searchError == nil
    }

    private var queryLooksLikeWebsite: Bool {
        BrightspaceParser.websiteHost(from: query) != nil
    }

    private var resolvedHost: String? {
        if let selected {
            return selected.host
        }
        return BrightspaceParser.websiteHost(from: query)
    }

    private var canSubmit: Bool {
        resolvedHost != nil && !isWorking
    }

    private func openSelectedSite() {
        do {
            let host = try BrightspaceParser.normalizedHost(resolvedHost ?? query)
            if selected == nil {
                selected = BrightspaceInstitution(name: host, host: host, isCustom: true)
            }
            errorMessage = nil
            showBrowser = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func searchSchools() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchError = nil

        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            if let host = BrightspaceParser.websiteHost(from: trimmed) {
                selected = BrightspaceInstitution(name: "Use this website", host: host, isCustom: true)
            } else if selected?.isCustom == true {
                selected = nil
            }
            return
        }

        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }

        isSearching = true
        defer { isSearching = false }

        do {
            let found = try await BrightspaceInstitutionSearch.search(trimmed)
            guard !Task.isCancelled else { return }
            results = found
            if let match = BrightspaceInstitutionSearch.suggestedSelection(in: found, query: trimmed) {
                selected = match
            } else if let current = selected, found.contains(current) == false,
                      BrightspaceParser.websiteHost(from: trimmed) != current.host {
                selected = nil
            }
        } catch is CancellationError {
            return
        } catch {
            results = []
            if let host = BrightspaceParser.websiteHost(from: trimmed) {
                let custom = BrightspaceInstitution(name: "Use this website", host: host, isCustom: true)
                results = [custom]
                selected = custom
                searchError = nil
            } else {
                searchError = "Couldn’t search schools. Check your connection, or paste your Brightspace website instead."
            }
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

#Preview("Brightspace school search") {
    BrightspaceConnectSheet(lastHost: "brightspace.usc.edu") { _ in }
}

struct BrightspaceSignInView: View {
    let host: String
    let onSignedIn: (BrightspaceStoredAuth) -> Void
    let onCancel: () -> Void

    @State private var isCapturing = false

    var body: some View {
        NavigationStack {
            ZStack {
                BrightspaceWebView(
                    host: host,
                    onSignedIn: { auth in
                        guard !isCapturing else { return }
                        isCapturing = true
                        onSignedIn(auth)
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                if isCapturing {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("Signed in — importing classes…")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(22)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .background(LockedBackground())
            .navigationTitle("Brightspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isCapturing)
                }
            }
            .safeAreaInset(edge: .top) {
                Text("Sign in with your school account. If you’re already signed in, Locked continues on its own.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
        }
        .tint(.lockedIndigo)
        .interactiveDismissDisabled(isCapturing)
    }
}

private struct BrightspaceWebView: UIViewRepresentable {
    let host: String
    let onSignedIn: (BrightspaceStoredAuth) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(host: host, onSignedIn: onSignedIn)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = BrightspaceConfig.safariUserAgent
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.webView = webView
        configuration.websiteDataStore.httpCookieStore.add(context.coordinator)

        webView.load(URLRequest(url: BrightspaceParser.homeURL(for: host)))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onSignedIn = onSignedIn
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.websiteDataStore.httpCookieStore.remove(coordinator)
        coordinator.webView = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver {
        let host: String
        var onSignedIn: (BrightspaceStoredAuth) -> Void
        weak var webView: WKWebView?
        private var finished = false

        init(host: String, onSignedIn: @escaping (BrightspaceStoredAuth) -> Void) {
            self.host = host
            self.onSignedIn = onSignedIn
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            inspectCookies(currentURL: webView.url)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            inspectCookies(currentURL: webView.url)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        nonisolated func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            Task { @MainActor in
                self.inspectCookies(currentURL: self.webView?.url)
            }
        }

        private func inspectCookies(currentURL: URL?) {
            guard !finished else { return }
            let store = webView?.configuration.websiteDataStore.httpCookieStore ?? WKWebsiteDataStore.default().httpCookieStore
            store.getAllCookies { [weak self] cookies in
                guard let self, !self.finished else { return }
                guard let auth = BrightspaceParser.session(from: cookies, host: self.host, currentURL: currentURL) else {
                    return
                }
                self.finished = true
                DispatchQueue.main.async {
                    self.onSignedIn(auth)
                }
            }
        }
    }
}

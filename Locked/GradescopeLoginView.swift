import SwiftUI
import WebKit

struct GradescopeSignInView: View {
    let onConnect: (GradescopeStoredAuth) async throws -> Void
    let onCancel: () -> Void

    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                GradescopeWebView(
                    onSignedIn: { auth in
                        guard !isWorking else { return }
                        Task { await finish(auth) }
                    }
                )
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(!isWorking)

                if isWorking {
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
            .navigationTitle("Gradescope")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isWorking)
                }
            }
            .safeAreaInset(edge: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sign in on gradescope.com the usual way — email, password, or school SSO. If you’re already signed in, Locked continues on its own.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.lockedRose)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
        .tint(.lockedIndigo)
        .interactiveDismissDisabled(isWorking)
    }

    private func finish(_ auth: GradescopeStoredAuth) async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await onConnect(auth)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct GradescopeWebView: UIViewRepresentable {
    let onSignedIn: (GradescopeStoredAuth) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSignedIn: onSignedIn)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = GradescopeConfig.safariUserAgent
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.webView = webView
        configuration.websiteDataStore.httpCookieStore.add(context.coordinator)

        webView.load(URLRequest(url: GradescopeConfig.accountURL))
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
        var onSignedIn: (GradescopeStoredAuth) -> Void
        weak var webView: WKWebView?
        private var finished = false

        init(onSignedIn: @escaping (GradescopeStoredAuth) -> Void) {
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
                guard let auth = GradescopeParser.session(from: cookies, currentURL: currentURL) else {
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

#Preview("Gradescope sign-in") {
    GradescopeSignInView(onConnect: { _ in }, onCancel: {})
}

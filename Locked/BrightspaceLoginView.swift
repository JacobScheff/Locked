import SwiftUI
import WebKit

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

import SwiftUI
import WebKit

struct GradescopeSignInView: View {
    let onConnect: (GradescopeStoredAuth) async throws -> Void
    let onCancel: () -> Void

    @StateObject private var bridge = GradescopeWebBridge()
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var captureID = 0

    var body: some View {
        NavigationStack {
            ZStack {
                GradescopeWebView(bridge: bridge, captureID: captureID) { auth in
                    Task { await finish(auth) }
                }
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
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await importNow() }
                } label: {
                    Text("I’m signed in — import classes")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isWorking ? LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing) : LockedTheme.karmaGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(isWorking)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.bar)
            }
        }
        .tint(.lockedIndigo)
        .interactiveDismissDisabled(isWorking)
    }

    private func importNow() async {
        guard !isWorking else { return }
        do {
            guard let auth = try await bridge.captureAuth(force: true) else {
                errorMessage = "Sign in first. When you can see your Gradescope classes, tap import."
                return
            }
            await finish(auth)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finish(_ auth: GradescopeStoredAuth) async {
        guard !isWorking else { return }
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await onConnect(auth)
        } catch {
            captureID += 1
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class GradescopeWebBridge: ObservableObject {
    weak var webView: WKWebView?

    func captureAuth(force: Bool) async throws -> GradescopeStoredAuth? {
        guard let webView else { return nil }
        let pageLooksSignedIn = await webView.gradescopePageLooksSignedIn()
        let cookies = await webView.gradescopeCookies()
        return GradescopeParser.session(
            from: cookies,
            currentURL: webView.url,
            pageLooksSignedIn: pageLooksSignedIn,
            force: force
        )
    }
}

private struct GradescopeWebView: UIViewRepresentable {
    let bridge: GradescopeWebBridge
    let captureID: Int
    let onSignedIn: (GradescopeStoredAuth) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge, onSignedIn: onSignedIn)
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
        bridge.webView = webView

        webView.load(URLRequest(url: GradescopeConfig.loginURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onSignedIn = onSignedIn
        context.coordinator.bridge = bridge
        bridge.webView = uiView
        context.coordinator.resetIfNeeded(captureID)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.webView = nil
        if coordinator.bridge.webView === uiView {
            coordinator.bridge.webView = nil
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var bridge: GradescopeWebBridge
        var onSignedIn: (GradescopeStoredAuth) -> Void
        weak var webView: WKWebView?
        private var finished = false
        private var lastCaptureID = 0
        private var inspectTask: Task<Void, Never>?

        init(bridge: GradescopeWebBridge, onSignedIn: @escaping (GradescopeStoredAuth) -> Void) {
            self.bridge = bridge
            self.onSignedIn = onSignedIn
        }

        func resetIfNeeded(_ captureID: Int) {
            guard captureID != lastCaptureID else { return }
            lastCaptureID = captureID
            finished = false
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            scheduleInspect()
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

        private func scheduleInspect() {
            inspectTask?.cancel()
            inspectTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, !finished, let webView else { return }
                do {
                    guard let auth = try await bridge.captureAuth(force: false) else { return }
                    finished = true
                    onSignedIn(auth)
                } catch {
                    return
                }
            }
        }
    }
}

private extension WKWebView {
    func gradescopePageLooksSignedIn() async -> Bool {
        await withCheckedContinuation { continuation in
            evaluateJavaScript(GradescopeConfig.signedInProbe) { result, _ in
                continuation.resume(returning: (result as? Bool) == true)
            }
        }
    }

    func gradescopeCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }
}

#Preview("Gradescope sign-in") {
    GradescopeSignInView(onConnect: { _ in }, onCancel: {})
}

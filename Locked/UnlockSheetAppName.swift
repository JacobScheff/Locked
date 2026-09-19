import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit

/// Visible title on the unlock sheet. The real name is never drawn here.
struct UnlockSheetAppName: View {
    var body: some View {
        Text("Locked app")
            .font(.title3.weight(.bold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel("Locked app")
    }
}

/// Prints the tapped app's name. Host this on Home, not in the sheet, so the
/// Screen Time label cannot appear on the confirm UI.
struct UnlockAppNamePrinter: View {
    var knownName: String?
    var token: ApplicationToken?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .background {
                if let token, sanitized(knownName) == nil {
                    TokenNameProbe(token: token, onName: Self.log)
                        .frame(width: 0, height: 0)
                }
            }
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    static func log(_ name: String) {
        print("Unlock sheet app name: \(name)")
    }

    private func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "Locked app" ? nil : trimmed
    }
}

private struct TokenNameProbe: UIViewControllerRepresentable {
    let token: ApplicationToken
    var onName: (String) -> Void

    func makeUIViewController(context: Context) -> TokenNameProbeController {
        TokenNameProbeController(token: token, onName: onName)
    }

    func updateUIViewController(_ controller: TokenNameProbeController, context: Context) {
        controller.onName = onName
        controller.read(token)
    }
}

private final class TokenNameProbeController: UIViewController {
    var token: ApplicationToken
    var onName: (String) -> Void

    private var host: UIHostingController<TokenProbeLabel>?
    private var attemptsRemaining = 24
    private var didRead = false

    init(token: ApplicationToken, onName: @escaping (String) -> Void) {
        self.token = token
        self.onName = onName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        installProbe()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scheduleRead()
    }

    func read(_ token: ApplicationToken) {
        if self.token != token {
            self.token = token
            didRead = false
            attemptsRemaining = 24
            installProbe()
        }
        scheduleRead()
    }

    private func installProbe() {
        host?.willMove(toParent: nil)
        host?.view.removeFromSuperview()
        host?.removeFromParent()

        let host = UIHostingController(rootView: TokenProbeLabel(token: token))
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        host.view.alpha = 0.01
        addChild(host)
        view.addSubview(host.view)
        host.view.frame = CGRect(x: -1000, y: -1000, width: 320, height: 44)
        host.didMove(toParent: self)
        self.host = host
    }

    private func scheduleRead() {
        view.layoutIfNeeded()
        host?.view.layoutIfNeeded()
        DispatchQueue.main.async { [weak self] in
            self?.capture()
        }
    }

    private func capture() {
        guard !didRead, let host else { return }
        if let name = firstName(in: host.view) {
            didRead = true
            UsageStore.saveToken(token, for: name)
            onName(name)
            return
        }
        guard attemptsRemaining > 0 else { return }
        attemptsRemaining -= 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.capture()
        }
    }

    private func firstName(in view: UIView) -> String? {
        if let label = view as? UILabel {
            let text = label.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty, text != "Locked app" { return text }
        }
        let accessibility = view.accessibilityLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !accessibility.isEmpty, accessibility != "Locked app" { return accessibility }
        return view.subviews.lazy.compactMap(firstName(in:)).first
    }
}

private struct TokenProbeLabel: View {
    let token: ApplicationToken

    var body: some View {
        Label(token)
            .labelStyle(.titleOnly)
            .id(TokenCoding.id(for: token))
    }
}

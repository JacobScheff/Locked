import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit

/// Screen Time's `Label(token)` always leading-aligns its title. Resolve the
/// name, then draw it with a full-width centered `UILabel`.
struct UnlockSheetAppName: View {
    var title: String
    var token: ApplicationToken?

    @State private var capturedName = ""

    var body: some View {
        CenteredSheetNameLabel(text: displayName)
            .frame(maxWidth: .infinity)
            .background {
                if let token, needsTokenName {
                    TokenNameReader(token: token, name: $capturedName)
                        .frame(width: 0, height: 0)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(displayName)
            .onAppear {
                if capturedName.isEmpty, let token, let cached = TokenNameCache.name(for: token) {
                    capturedName = cached
                }
            }
    }

    private var displayName: String {
        if let known = sanitized(title) { return known }
        if let captured = sanitized(capturedName) { return captured }
        if let token, let cached = TokenNameCache.name(for: token) { return cached }
        if let token, let mapped = UsageStore.displayName(for: token) { return mapped }
        return "Locked app"
    }

    private var needsTokenName: Bool {
        sanitized(title) == nil
    }

    private func sanitized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "Locked app" ? nil : trimmed
    }
}

private struct CenteredSheetNameLabel: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> CenteredSheetNameView {
        CenteredSheetNameView()
    }

    func updateUIView(_ view: CenteredSheetNameView, context: Context) {
        view.apply(text: text)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: CenteredSheetNameView, context: Context) -> CGSize? {
        uiView.apply(text: text)
        return uiView.fittedSize(forWidth: proposal.width ?? 280)
    }
}

private final class CenteredSheetNameView: UIView {
    private let label = UILabel()

    init() {
        super.init(frame: .zero)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        apply(text: "")
    }

    required init?(coder: NSCoder) { nil }

    func fittedSize(forWidth width: CGFloat) -> CGSize {
        let fitted = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(fitted.height, label.font.lineHeight))
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : 280
        return fittedSize(forWidth: width)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }

    func apply(text: String) {
        let size = UIFont.preferredFont(forTextStyle: .title3).pointSize
        let base = UIFont.systemFont(ofSize: size, weight: .bold)
        let font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
        label.font = font
        label.textColor = .label
        label.textAlignment = .center
        label.text = text
        invalidateIntrinsicContentSize()
    }
}

private enum TokenNameCache {
    static var names: [ApplicationToken: String] = [:]

    static func name(for token: ApplicationToken) -> String? {
        names[token]
    }

    static func store(_ name: String, for token: ApplicationToken) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "Locked app" else { return }
        names[token] = trimmed
        UsageStore.saveToken(token, for: trimmed)
    }
}

private struct TokenNameReader: UIViewControllerRepresentable {
    let token: ApplicationToken
    @Binding var name: String

    func makeUIViewController(context: Context) -> TokenNameReaderController {
        TokenNameReaderController(token: token)
    }

    func updateUIViewController(_ controller: TokenNameReaderController, context: Context) {
        controller.token = token
        controller.onName = { captured in
            TokenNameCache.store(captured, for: token)
            if name != captured {
                name = captured
            }
        }
        controller.captureIfNeeded()
    }
}

private final class TokenNameReaderController: UIViewController {
    var token: ApplicationToken
    var onName: ((String) -> Void)?

    private var host: UIHostingController<TokenProbeLabel>?
    private var attemptsRemaining = 24
    private var didCapture = false
    private var probedToken: ApplicationToken?

    init(token: ApplicationToken) {
        self.token = token
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
        captureIfNeeded()
    }

    func captureIfNeeded() {
        if probedToken != token {
            didCapture = false
            attemptsRemaining = 24
            installProbe()
        }
        guard !didCapture else { return }
        view.layoutIfNeeded()
        host?.view.layoutIfNeeded()
        DispatchQueue.main.async { [weak self] in
            self?.capture()
        }
    }

    private func installProbe() {
        host?.willMove(toParent: nil)
        host?.view.removeFromSuperview()
        host?.removeFromParent()

        let host = UIHostingController(rootView: TokenProbeLabel(token: token))
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        addChild(host)
        view.addSubview(host.view)
        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 44)
        host.didMove(toParent: self)
        self.host = host
        probedToken = token
    }

    private func capture() {
        guard !didCapture, let host else { return }
        if let text = firstName(in: host.view) {
            didCapture = true
            onName?(text)
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
            if !text.isEmpty { return text }
        }
        let accessibility = view.accessibilityLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !accessibility.isEmpty { return accessibility }
        for subview in view.subviews {
            if let text = firstName(in: subview) { return text }
        }
        return nil
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

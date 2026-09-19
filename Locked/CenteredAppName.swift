import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit

/// Screen Time `Label` always leading-aligns its title. Resolve the name,
/// then draw it with a real centered `UILabel`.
struct CenteredAppName: View {
    enum Style {
        case grid
        case sheet
    }

    var token: ApplicationToken?
    var title: String?
    var style: Style

    @State private var resolvedName = ""

    private var displayName: String {
        if let known = sanitized(title), known != "Locked app" {
            return known
        }
        if !resolvedName.isEmpty {
            return resolvedName
        }
        if let token, let cached = TokenNameCache.name(for: token) {
            return cached
        }
        if let token {
            return invertedTokenMapName(for: token) ?? ""
        }
        return sanitized(title) ?? ""
    }

    var body: some View {
        CenteredNameLabel(text: displayName, style: style)
            .frame(maxWidth: .infinity)
            .background {
                if let token, shouldReadTokenName {
                    TokenNameReader(token: token, name: $resolvedName)
                        .frame(width: 0, height: 0)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(displayName.isEmpty ? "Locked app" : displayName)
            .onAppear {
                if resolvedName.isEmpty, let token, let cached = TokenNameCache.name(for: token) {
                    resolvedName = cached
                }
            }
    }

    private var shouldReadTokenName: Bool {
        let known = sanitized(title)
        return known == nil || known == "Locked app"
    }

    private func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func invertedTokenMapName(for token: ApplicationToken) -> String? {
        UsageStore.loadTokenMap().first(where: { $0.value == token })?.key
    }
}

private enum TokenNameCache {
    static var names: [ApplicationToken: String] = [:]

    static func name(for token: ApplicationToken) -> String? {
        names[token]
    }

    static func store(_ name: String, for token: ApplicationToken) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        names[token] = trimmed
    }
}

private struct CenteredNameLabel: UIViewRepresentable {
    let text: String
    let style: CenteredAppName.Style

    func makeUIView(context: Context) -> CenteredNameView {
        CenteredNameView(style: style)
    }

    func updateUIView(_ view: CenteredNameView, context: Context) {
        view.apply(text: text, style: style)
    }
}

private final class CenteredNameView: UIView {
    private let label = UILabel()

    init(style: CenteredAppName.Style) {
        super.init(frame: .zero)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
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
        apply(text: "", style: style)
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: CGSize {
        let lineHeight = label.font?.lineHeight ?? 13
        return CGSize(width: UIView.noIntrinsicMetric, height: max(label.intrinsicContentSize.height, lineHeight))
    }

    func apply(text: String, style: CenteredAppName.Style) {
        switch style {
        case .grid:
            label.font = Self.roundedFont(size: 11, weight: .medium)
            label.adjustsFontForContentSizeCategory = false
            label.minimumScaleFactor = 0.75
        case .sheet:
            label.font = Self.roundedFont(
                size: UIFont.preferredFont(forTextStyle: .title3).pointSize,
                weight: .bold
            )
            label.adjustsFontForContentSizeCategory = true
            label.minimumScaleFactor = 0.85
        }
        label.textColor = .label
        label.text = text
        label.textAlignment = .center
        invalidateIntrinsicContentSize()
    }

    private static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
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

    init(token: ApplicationToken) {
        self.token = token
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false

        let host = UIHostingController(rootView: TokenProbeLabel(token: token))
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        addChild(host)
        view.addSubview(host.view)
        host.view.frame = CGRect(x: 0, y: 0, width: 240, height: 36)
        host.didMove(toParent: self)
        self.host = host
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        captureIfNeeded()
    }

    func captureIfNeeded() {
        guard !didCapture else { return }
        view.layoutIfNeeded()
        host?.view.layoutIfNeeded()
        DispatchQueue.main.async { [weak self] in
            self?.capture()
        }
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
        if !accessibility.isEmpty {
            return accessibility
        }
        for subview in view.subviews {
            if let text = firstName(in: subview) {
                return text
            }
        }
        return nil
    }
}

private struct TokenProbeLabel: View {
    let token: ApplicationToken

    var body: some View {
        Label(token)
            .labelStyle(.titleOnly)
    }
}

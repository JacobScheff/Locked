import FamilyControls
import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ManagedSettingsUI.ShieldConfiguration {
        lockedConfiguration(for: application.token)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ManagedSettingsUI.ShieldConfiguration {
        lockedConfiguration(for: application.token)
    }

    override func configuration(shielding webDomain: WebDomain) -> ManagedSettingsUI.ShieldConfiguration {
        lockedConfiguration(for: nil)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ManagedSettingsUI.ShieldConfiguration {
        lockedConfiguration(for: nil)
    }

    private func lockedConfiguration(for token: ApplicationToken?) -> ManagedSettingsUI.ShieldConfiguration {
        let keys = Int(Economy.keys().rounded(.towardZero))
        let karma = Int(Economy.karma().rounded(.towardZero))
        let cost = token.map { KeyUnlock.cost(for: $0) }
            ?? KeyUnlock.cost(usageSeconds: 0, lockedCount: LockedTokenStore.load().count)
        let canAfford = keys >= cost
        let confirming = token.map { ShieldUnlockPrompt.isConfirming($0) } ?? false
        let state = ShieldLook.State(
            confirming: confirming && canAfford,
            canAfford: canAfford,
            cost: cost,
            keys: keys,
            karma: karma
        )

        return ManagedSettingsUI.ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: ShieldLook.indigo,
            icon: ShieldArtwork.ledger(for: state),
            // System chrome always draws the icon above these labels. The
            // heading lives in the image so the ledger sits under the text;
            // keep the real copy here (invisible) for VoiceOver.
            title: .init(text: state.title, color: .clear),
            subtitle: .init(text: state.subtitle, color: .clear),
            primaryButtonLabel: .init(text: state.primaryTitle, color: .white),
            primaryButtonBackgroundColor: state.primaryBackground,
            secondaryButtonLabel: .init(text: state.secondaryTitle, color: UIColor.white.withAlphaComponent(0.88))
        )
    }
}

private enum ShieldLook {
    static let indigo = UIColor(red: 0.22, green: 0.18, blue: 0.58, alpha: 1)
    static let keyButton = UIColor(red: 0.62, green: 0.34, blue: 0.04, alpha: 1)
    static let mutedButton = UIColor(red: 0.30, green: 0.28, blue: 0.52, alpha: 1)
    static let amber = UIColor(red: 0.97, green: 0.70, blue: 0.22, alpha: 1)
    static let violet = UIColor(red: 0.78, green: 0.58, blue: 1.0, alpha: 1)
    static let rose = UIColor(red: 0.98, green: 0.38, blue: 0.48, alpha: 1)
    static let teal = UIColor(red: 0.28, green: 0.86, blue: 0.78, alpha: 1)

    struct State {
        var confirming: Bool
        var canAfford: Bool
        var cost: Int
        var keys: Int
        var karma: Int

        var remaining: Int { max(0, keys - cost) }
        var shortfall: Int { max(0, cost - keys) }

        var title: String {
            if confirming { return "Unlock until Sunday?" }
            if canAfford { return "This app is locked" }
            return "Not enough keys"
        }

        var subtitle: String {
            if confirming {
                return "It stays open until the next weekly lock."
            }
            if canAfford {
                return "Spend keys to open it until next Sunday."
            }
            return "Finish assignments in Locked to earn more."
        }

        var primaryTitle: String {
            if confirming { return "Unlock" }
            if canAfford { return "Use Keys" }
            return shortfall == 1 ? "Need 1 more key" : "Need \(shortfall) more keys"
        }

        var secondaryTitle: String {
            confirming ? "Cancel" : "Keep locked"
        }

        var primaryBackground: UIColor {
            canAfford || confirming ? ShieldLook.keyButton : ShieldLook.mutedButton
        }
    }
}

private enum ShieldArtwork {
    static func ledger(for state: ShieldLook.State) -> UIImage {
        let size = CGSize(width: 640, height: 640)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let content = CGRect(origin: .zero, size: size).insetBy(dx: 24, dy: 16)
            var y = content.minY

            y += drawWrapped(
                state.title,
                font: roundedFont(size: 44, weight: .bold),
                color: .white,
                in: CGRect(x: content.minX, y: y, width: content.width, height: 120)
            )
            y += 8
            y += drawWrapped(
                state.subtitle,
                font: roundedFont(size: 24, weight: .medium),
                color: UIColor.white.withAlphaComponent(0.78),
                in: CGRect(x: content.minX, y: y, width: content.width, height: 80)
            )
            y += 28

            let rowHeight: CGFloat = 78
            drawAlignedRow(
                label: "Keys",
                value: "\(state.keys)",
                color: ShieldLook.amber,
                in: CGRect(x: content.minX, y: y, width: content.width, height: rowHeight)
            )
            y += rowHeight
            drawAlignedRow(
                label: "Karma",
                value: "\(state.karma)",
                color: ShieldLook.violet,
                in: CGRect(x: content.minX, y: y, width: content.width, height: rowHeight)
            )
            y += rowHeight + 8
            drawAlignedRow(
                label: "Cost",
                value: "−\(state.cost)",
                color: ShieldLook.rose,
                in: CGRect(x: content.minX, y: y, width: content.width, height: rowHeight)
            )
            y += rowHeight + 10

            UIColor.white.withAlphaComponent(0.28).setStroke()
            let rule = UIBezierPath()
            rule.move(to: CGPoint(x: content.minX, y: y))
            rule.addLine(to: CGPoint(x: content.maxX, y: y))
            rule.lineWidth = 3
            rule.lineCapStyle = .round
            rule.stroke()
            y += 16

            if state.canAfford {
                drawAlignedRow(
                    label: "Left",
                    value: "\(state.remaining)",
                    color: ShieldLook.teal,
                    in: CGRect(x: content.minX, y: y, width: content.width, height: rowHeight)
                )
            } else {
                drawAlignedRow(
                    label: "Need",
                    value: "\(state.shortfall)",
                    color: ShieldLook.rose,
                    in: CGRect(x: content.minX, y: y, width: content.width, height: rowHeight)
                )
            }
        }
    }

    @discardableResult
    private static func drawWrapped(_ text: String, font: UIFont, color: UIColor, in rect: CGRect) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: rect.width, height: rect.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )
        let drawn = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: ceil(bounds.height))
        (text as NSString).draw(with: drawn, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
        return ceil(bounds.height)
    }

    private static func drawAlignedRow(label: String, value: String, color: UIColor, in rect: CGRect) {
        let labelFont = roundedFont(size: 28, weight: .semibold)
        let valueFont = roundedFont(size: 52, weight: .heavy)
        let labelColor = UIColor.white.withAlphaComponent(0.78)
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        (label as NSString).draw(
            in: rect.offsetBy(dx: 0, dy: (rect.height - labelFont.lineHeight) / 2),
            withAttributes: [
                .font: labelFont,
                .foregroundColor: labelColor,
                .paragraphStyle: style
            ]
        )

        let valueStyle = NSMutableParagraphStyle()
        valueStyle.alignment = .right
        (value as NSString).draw(
            in: rect.offsetBy(dx: 0, dy: (rect.height - valueFont.lineHeight) / 2),
            withAttributes: [
                .font: valueFont,
                .foregroundColor: color,
                .paragraphStyle: valueStyle
            ]
        )
    }

    private static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

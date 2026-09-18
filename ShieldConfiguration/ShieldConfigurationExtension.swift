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
            title: .init(text: state.title, color: .white),
            subtitle: .init(text: state.subtitle, color: UIColor.white.withAlphaComponent(0.78)),
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
            return shortfall == 1 ? "Need 1 more key" : "Need \(ShieldLook.format(shortfall)) more keys"
        }

        var secondaryTitle: String {
            confirming ? "Cancel" : "Keep locked"
        }

        var primaryBackground: UIColor {
            canAfford || confirming ? ShieldLook.keyButton : ShieldLook.mutedButton
        }
    }

    static func format(_ value: Int) -> String {
        formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}

private enum ShieldArtwork {
    static func ledger(for state: ShieldLook.State) -> UIImage {
        // The system icon slot is small and fixed. Fill it with the equation
        // only — title and subtitle now use the real (much larger) labels.
        let size = CGSize(width: 200, height: 200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            let content = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
            var y = content.minY

            drawKarma(state.karma, in: CGRect(x: content.minX, y: y, width: content.width, height: 28))
            y += 30

            let rowHeight: CGFloat = 50
            drawAlignedRow(
                label: "KEYS",
                value: ShieldLook.format(state.keys),
                color: ShieldLook.amber,
                in: CGRect(x: content.minX, y: y, width: content.width, height: rowHeight)
            )
            y += rowHeight
            drawAlignedRow(
                label: "COST",
                value: "−\(ShieldLook.format(state.cost))",
                color: ShieldLook.rose,
                in: CGRect(x: content.minX, y: y, width: content.width, height: rowHeight)
            )
            y += rowHeight + 1

            UIColor.white.withAlphaComponent(0.34).setStroke()
            let rule = UIBezierPath()
            rule.move(to: CGPoint(x: content.minX, y: y))
            rule.addLine(to: CGPoint(x: content.maxX, y: y))
            rule.lineWidth = 2
            rule.lineCapStyle = .round
            rule.stroke()
            y += 3

            if state.canAfford {
                drawAlignedRow(
                    label: "LEFT",
                    value: ShieldLook.format(state.remaining),
                    color: ShieldLook.teal,
                    in: CGRect(x: content.minX, y: y, width: content.width, height: rowHeight)
                )
            } else {
                drawAlignedRow(
                    label: "NEED",
                    value: ShieldLook.format(state.shortfall),
                    color: ShieldLook.rose,
                    in: CGRect(x: content.minX, y: y, width: content.width, height: rowHeight)
                )
            }
        }
    }

    private static func drawKarma(_ karma: Int, in rect: CGRect) {
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        ("\(karma)" as NSString).draw(
            in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 18),
            withAttributes: [
                .font: roundedFont(size: 16, weight: .heavy),
                .foregroundColor: ShieldLook.violet,
                .paragraphStyle: style
            ]
        )
        ("KARMA" as NSString).draw(
            in: CGRect(x: rect.minX, y: rect.minY + 16, width: rect.width, height: 10),
            withAttributes: [
                .font: roundedFont(size: 8, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.58),
                .paragraphStyle: style,
                .kern: 0.8
            ]
        )
    }

    private static func drawAlignedRow(label: String, value: String, color: UIColor, in rect: CGRect) {
        let labelFont = roundedFont(size: 13, weight: .bold)
        let labelColor = UIColor.white.withAlphaComponent(0.72)
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        (label as NSString).draw(
            in: rect.offsetBy(dx: 0, dy: (rect.height - labelFont.lineHeight) / 2),
            withAttributes: [
                .font: labelFont,
                .foregroundColor: labelColor,
                .paragraphStyle: style,
                .kern: 0.8
            ]
        )

        let valueWidth = rect.width * 0.68
        let valueRect = CGRect(
            x: rect.maxX - valueWidth,
            y: rect.minY,
            width: valueWidth,
            height: rect.height
        )
        drawFittedValue(value, color: color, in: valueRect, maxSize: 44)
    }

    private static func drawFittedValue(_ value: String, color: UIColor, in rect: CGRect, maxSize: CGFloat) {
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        style.lineBreakMode = .byClipping

        var size = maxSize
        var font = roundedFont(size: size, weight: .heavy)
        let text = value as NSString
        while size > 18 {
            let width = text.size(withAttributes: [.font: font]).width
            if width <= rect.width { break }
            size -= 2
            font = roundedFont(size: size, weight: .heavy)
        }

        text.draw(
            in: rect.offsetBy(dx: 0, dy: (rect.height - font.lineHeight) / 2),
            withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: style
            ]
        )
    }

    private static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

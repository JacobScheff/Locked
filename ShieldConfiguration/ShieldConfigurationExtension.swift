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
            subtitle: .init(text: state.subtitle, color: UIColor.white.withAlphaComponent(0.82)),
            primaryButtonLabel: .init(text: state.primaryTitle, color: state.primaryTitleColor),
            primaryButtonBackgroundColor: state.primaryBackground,
            secondaryButtonLabel: .init(text: state.secondaryTitle, color: UIColor.white.withAlphaComponent(0.88))
        )
    }
}

private enum ShieldLook {
    static let indigo = UIColor(red: 0.22, green: 0.18, blue: 0.58, alpha: 1)
    static let keyButton = UIColor(red: 0.93, green: 0.62, blue: 0.16, alpha: 1)
    static let mutedButton = UIColor(red: 0.30, green: 0.28, blue: 0.52, alpha: 1)
    static let amber = UIColor(red: 0.97, green: 0.70, blue: 0.22, alpha: 1)
    static let violet = UIColor(red: 0.72, green: 0.52, blue: 0.98, alpha: 1)
    static let rose = UIColor(red: 0.93, green: 0.33, blue: 0.46, alpha: 1)
    static let teal = UIColor(red: 0.18, green: 0.78, blue: 0.72, alpha: 1)

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

        var primaryTitleColor: UIColor {
            canAfford || confirming ? UIColor(red: 0.22, green: 0.12, blue: 0.04, alpha: 1) : .white
        }
    }
}

private enum ShieldArtwork {
    static func ledger(for state: ShieldLook.State) -> UIImage {
        let size = CGSize(width: 360, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let card = CGRect(origin: .zero, size: size).insetBy(dx: 16, dy: 16)

            cg.setShadow(
                offset: CGSize(width: 0, height: 10),
                blur: 20,
                color: UIColor.black.withAlphaComponent(0.32).cgColor
            )
            UIBezierPath(roundedRect: card, cornerRadius: 36).fill()
            cg.setShadow(offset: .zero, blur: 0, color: nil)

            let top = UIColor(red: 0.34, green: 0.28, blue: 0.78, alpha: 1)
            let bottom = UIColor(red: 0.20, green: 0.16, blue: 0.48, alpha: 1)
            cg.saveGState()
            UIBezierPath(roundedRect: card, cornerRadius: 36).addClip()
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [top.cgColor, bottom.cgColor] as CFArray,
                locations: [0, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: card.origin,
                    end: CGPoint(x: card.maxX, y: card.maxY),
                    options: []
                )
            }
            cg.restoreGState()

            UIColor.white.withAlphaComponent(0.20).setStroke()
            let stroke = UIBezierPath(roundedRect: card.insetBy(dx: 1, dy: 1), cornerRadius: 35)
            stroke.lineWidth = 2
            stroke.stroke()

            let content = card.insetBy(dx: 24, dy: 22)
            var y = content.minY

            drawLabel("THIS WEEK", in: CGRect(x: content.minX, y: y, width: content.width, height: 16))
            y += 22

            let chipHeight: CGFloat = 78
            let chipGap: CGFloat = 10
            let chipWidth = (content.width - chipGap) / 2
            drawBalanceChip(
                icon: "key.fill",
                value: "\(state.keys)",
                caption: "Keys",
                tint: ShieldLook.amber,
                in: CGRect(x: content.minX, y: y, width: chipWidth, height: chipHeight)
            )
            drawBalanceChip(
                icon: "star.fill",
                value: "\(state.karma)",
                caption: "Karma",
                tint: ShieldLook.violet,
                in: CGRect(x: content.minX + chipWidth + chipGap, y: y, width: chipWidth, height: chipHeight)
            )
            y += chipHeight + 20

            drawLabel("UNLOCK", in: CGRect(x: content.minX, y: y, width: content.width, height: 16))
            y += 20

            drawLedgerRow(
                text: "− \(state.cost)",
                detail: state.cost == 1 ? "key" : "keys",
                color: ShieldLook.rose,
                in: CGRect(x: content.minX, y: y, width: content.width, height: 52)
            )
            y += 60

            UIColor.white.withAlphaComponent(0.22).setStroke()
            let rule = UIBezierPath()
            rule.move(to: CGPoint(x: content.minX, y: y))
            rule.addLine(to: CGPoint(x: content.maxX, y: y))
            rule.lineWidth = 2
            rule.lineCapStyle = .round
            rule.stroke()
            y += 16

            if state.canAfford {
                drawLedgerRow(
                    text: "\(state.remaining)",
                    detail: state.remaining == 1 ? "key left" : "keys left",
                    color: ShieldLook.teal,
                    in: CGRect(x: content.minX, y: y, width: content.width, height: 64)
                )
            } else {
                drawLedgerRow(
                    text: "\(state.shortfall)",
                    detail: state.shortfall == 1 ? "more key needed" : "more keys needed",
                    color: ShieldLook.rose,
                    in: CGRect(x: content.minX, y: y, width: content.width, height: 64)
                )
            }
        }
    }

    private static func drawBalanceChip(
        icon: String,
        value: String,
        caption: String,
        tint: UIColor,
        in rect: CGRect
    ) {
        UIColor.white.withAlphaComponent(0.10).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 20).fill()
        UIColor.white.withAlphaComponent(0.10).setStroke()
        let border = UIBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 20)
        border.lineWidth = 1
        border.stroke()

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        let symbol = UIImage(systemName: icon, withConfiguration: symbolConfig)?
            .withTintColor(tint, renderingMode: .alwaysOriginal)
        let iconSize = symbol?.size ?? .zero
        let iconRect = CGRect(
            x: rect.minX + 14,
            y: rect.minY + 14,
            width: iconSize.width,
            height: iconSize.height
        )
        symbol?.draw(in: iconRect)

        drawText(
            caption.uppercased(),
            font: roundedFont(size: 11, weight: .bold),
            color: UIColor.white.withAlphaComponent(0.62),
            in: CGRect(x: iconRect.maxX + 6, y: rect.minY + 16, width: rect.maxX - iconRect.maxX - 18, height: 14)
        )
        drawText(
            value,
            font: roundedFont(size: 30, weight: .heavy),
            color: .white,
            in: CGRect(x: rect.minX + 14, y: rect.maxY - 40, width: rect.width - 28, height: 34)
        )
    }

    private static func drawLedgerRow(text: String, detail: String, color: UIColor, in rect: CGRect) {
        let numberFont = roundedFont(size: 40, weight: .heavy)
        let numberHeight = numberFont.lineHeight
        drawText(text, font: numberFont, color: color, in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: numberHeight))
        drawText(
            detail,
            font: roundedFont(size: 14, weight: .semibold),
            color: color.withAlphaComponent(0.86),
            in: CGRect(x: rect.minX, y: rect.minY + numberHeight - 2, width: rect.width, height: 18)
        )
    }

    private static func drawLabel(_ text: String, in rect: CGRect) {
        drawText(
            text,
            font: roundedFont(size: 11, weight: .bold),
            color: UIColor.white.withAlphaComponent(0.52),
            in: rect
        )
    }

    private static func drawText(_ text: String, font: UIFont, color: UIColor, in rect: CGRect) {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style,
            .kern: text.count <= 4 ? 0.4 : 0.8
        ])
    }

    private static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

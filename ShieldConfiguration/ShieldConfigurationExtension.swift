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
            icon: ShieldArtwork.karmaBadge(state.karma),
            title: .init(text: state.title, color: .white),
            subtitle: .init(text: state.ledgerText, color: state.ledgerColor),
            primaryButtonLabel: .init(text: state.primaryTitle, color: state.primaryTitleColor),
            primaryButtonBackgroundColor: state.primaryBackground,
            secondaryButtonLabel: .init(text: state.secondaryTitle, color: UIColor.white.withAlphaComponent(0.88))
        )
    }
}

private enum ShieldLook {
    static let indigo = UIColor(red: 0.16, green: 0.12, blue: 0.38, alpha: 1)
    static let keyButton = UIColor.white
    static let mutedButton = UIColor(red: 0.28, green: 0.24, blue: 0.48, alpha: 1)
    static let amber = UIColor(red: 0.97, green: 0.70, blue: 0.22, alpha: 1)
    static let violet = UIColor(red: 0.78, green: 0.58, blue: 1.0, alpha: 1)
    static let rose = UIColor(red: 1.0, green: 0.42, blue: 0.50, alpha: 1)
    static let teal = UIColor(red: 0.36, green: 0.90, blue: 0.82, alpha: 1)

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

        var ledgerText: String {
            let current = ShieldLook.format(keys)
            let unlock = ShieldLook.format(cost)
            if canAfford {
                return "\(current) keys\n− \(unlock)\n\(ShieldLook.format(remaining)) left"
            }
            let need = ShieldLook.format(shortfall)
            return "\(current) keys\n− \(unlock)\nNeed \(need) more"
        }

        var ledgerColor: UIColor {
            canAfford ? UIColor.white.withAlphaComponent(0.92) : ShieldLook.rose
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

        var primaryTitleColor: UIColor {
            canAfford || confirming ? ShieldLook.indigo : .white
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
    static func karmaBadge(_ karma: Int) -> UIImage {
        let size = CGSize(width: 96, height: 96)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let valueStyle = NSMutableParagraphStyle()
            valueStyle.alignment = .center
            ("\(karma)" as NSString).draw(
                in: CGRect(x: 0, y: 18, width: size.width, height: 44),
                withAttributes: [
                    .font: roundedFont(size: 36, weight: .heavy),
                    .foregroundColor: ShieldLook.violet,
                    .paragraphStyle: valueStyle
                ]
            )
            ("KARMA" as NSString).draw(
                in: CGRect(x: 0, y: 62, width: size.width, height: 18),
                withAttributes: [
                    .font: roundedFont(size: 11, weight: .bold),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.62),
                    .paragraphStyle: valueStyle,
                    .kern: 1.1
                ]
            )
        }
    }

    private static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

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

        // The shield icon slot is small and fixed by the system, so the key
        // math lives in the title/subtitle labels where the type is large.
        return ManagedSettingsUI.ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: ShieldLook.indigo,
            icon: ShieldArtwork.glyph(for: state),
            title: .init(text: state.title, color: .white),
            subtitle: .init(text: state.ledger, color: state.ledgerColor),
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
    static let rose = UIColor(red: 0.98, green: 0.38, blue: 0.48, alpha: 1)

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

        var ledger: String {
            var lines = [
                "Keys  \(ShieldLook.format(keys))",
                "Cost  −\(ShieldLook.format(cost))",
            ]
            if canAfford {
                lines.append("Left  \(ShieldLook.format(remaining))")
            } else {
                lines.append("Need  \(ShieldLook.format(shortfall)) more")
            }
            lines.append("Karma  \(karma)")
            return lines.joined(separator: "\n")
        }

        var ledgerColor: UIColor {
            canAfford ? UIColor.white.withAlphaComponent(0.88) : ShieldLook.rose
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
    static func glyph(for state: ShieldLook.State) -> UIImage {
        let name = state.confirming ? "lock.open.fill" : (state.canAfford ? "key.fill" : "lock.fill")
        let tint = state.canAfford ? ShieldLook.amber : UIColor.white.withAlphaComponent(0.85)
        let config = UIImage.SymbolConfiguration(pointSize: 120, weight: .bold)
        return UIImage(systemName: name, withConfiguration: config)?
            .withTintColor(tint, renderingMode: .alwaysOriginal)
            ?? UIImage()
    }
}

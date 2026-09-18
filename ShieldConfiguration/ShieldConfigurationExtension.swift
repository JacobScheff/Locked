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
        Economy.seedNewInstallIfNeeded()
        let keys = Int(Economy.keys().rounded(.towardZero))
        let cost = token.map { KeyUnlock.cost(for: $0) } ?? KeyUnlock.cost(usageSeconds: 0, lockedCount: LockedTokenStore.load().count)
        let canAfford = keys >= cost
        let subtitle: String
        let primary: String
        if canAfford {
            subtitle = "\(cost) keys to unlock · you have \(keys)."
            primary = "Unlock · \(cost)"
        } else {
            subtitle = "Needs \(cost) keys, you have \(keys). Finish assignments in Locked to earn more."
            primary = "Need \(cost) keys"
        }

        return ManagedSettingsUI.ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor(red: 0.22, green: 0.18, blue: 0.58, alpha: 1),
            icon: UIImage(systemName: "lock.fill"),
            title: ManagedSettingsUI.ShieldConfiguration.Label(text: "Locked", color: .white),
            subtitle: ManagedSettingsUI.ShieldConfiguration.Label(
                text: subtitle,
                color: UIColor.white.withAlphaComponent(0.78)
            ),
            primaryButtonLabel: ManagedSettingsUI.ShieldConfiguration.Label(text: primary, color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.37, green: 0.38, blue: 0.96, alpha: 1),
            secondaryButtonLabel: ManagedSettingsUI.ShieldConfiguration.Label(
                text: "Not now",
                color: UIColor.white.withAlphaComponent(0.92)
            )
        )
    }
}

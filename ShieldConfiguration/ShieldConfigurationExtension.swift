import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ManagedSettingsUI.ShieldConfiguration {
        lockedConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ManagedSettingsUI.ShieldConfiguration {
        lockedConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ManagedSettingsUI.ShieldConfiguration {
        lockedConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ManagedSettingsUI.ShieldConfiguration {
        lockedConfiguration()
    }

    private func lockedConfiguration() -> ManagedSettingsUI.ShieldConfiguration {
        ManagedSettingsUI.ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor(red: 0.22, green: 0.18, blue: 0.58, alpha: 1),
            icon: UIImage(systemName: "lock.fill"),
            title: ManagedSettingsUI.ShieldConfiguration.Label(text: "Locked", color: .white),
            subtitle: ManagedSettingsUI.ShieldConfiguration.Label(
                text: "Finish assignments in Locked to earn Keys and unlock this app.",
                color: UIColor.white.withAlphaComponent(0.78)
            ),
            primaryButtonLabel: ManagedSettingsUI.ShieldConfiguration.Label(text: "OK", color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.37, green: 0.38, blue: 0.96, alpha: 1)
        )
    }
}

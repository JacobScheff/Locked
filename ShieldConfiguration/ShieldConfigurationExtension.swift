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
        let cost = token.map { KeyUnlock.cost(for: $0) }
            ?? KeyUnlock.cost(usageSeconds: 0, lockedCount: LockedTokenStore.load().count)
        let canAfford = keys >= cost
        let confirming = token.map { ShieldUnlockPrompt.isConfirming($0) } ?? false
        let state = ShieldLook.State(
            confirming: confirming && canAfford,
            canAfford: canAfford,
            cost: cost,
            keys: keys
        )

        return ManagedSettingsUI.ShieldConfiguration(
            backgroundBlurStyle: state.confirming ? .light : .dark,
            backgroundColor: state.background,
            icon: ShieldArtwork.seal(for: state),
            title: .init(text: state.title, color: state.titleColor),
            subtitle: .init(text: state.subtitle, color: state.subtitleColor),
            primaryButtonLabel: .init(text: state.primaryTitle, color: state.primaryForeground),
            primaryButtonBackgroundColor: state.primaryBackground,
            secondaryButtonLabel: .init(text: state.secondaryTitle, color: state.secondaryForeground)
        )
    }
}

private enum ShieldLook {
    static let indigo = UIColor(red: 0.22, green: 0.18, blue: 0.58, alpha: 1)
    static let indigoButton = UIColor(red: 0.37, green: 0.38, blue: 0.96, alpha: 1)
    static let indigoMuted = UIColor(red: 0.30, green: 0.28, blue: 0.52, alpha: 1)
    static let cream = UIColor(red: 0.96, green: 0.96, blue: 0.99, alpha: 1)
    static let ink = UIColor(red: 0.16, green: 0.14, blue: 0.32, alpha: 1)

    struct State {
        var confirming: Bool
        var canAfford: Bool
        var cost: Int
        var keys: Int

        var background: UIColor {
            confirming ? ShieldLook.cream : ShieldLook.indigo
        }

        var titleColor: UIColor {
            confirming ? ShieldLook.ink : .white
        }

        var subtitleColor: UIColor {
            confirming
                ? UIColor(red: 0.32, green: 0.30, blue: 0.42, alpha: 1)
                : UIColor.white.withAlphaComponent(0.82)
        }

        var title: String {
            if confirming { return "Spend \(cost) keys?" }
            return "This app is locked"
        }

        var subtitle: String {
            if confirming {
                let remaining = max(0, keys - cost)
                return "You’ll have \(remaining) left. This app stays open until next Sunday."
            }
            if canAfford {
                return "\(cost) keys until Sunday · you have \(keys)"
            }
            return "Needs \(cost) keys · you have \(keys). Finish assignments in Locked to earn more."
        }

        /// Confirm puts Cancel on the primary control so a double-tap
        /// on Use keys cannot spend. Spend is the secondary action.
        var primaryTitle: String {
            if confirming { return "Cancel" }
            if canAfford { return "Use keys" }
            return "Need \(cost) keys"
        }

        var secondaryTitle: String {
            if confirming { return "Spend \(cost) keys" }
            return "Keep locked"
        }

        var primaryBackground: UIColor {
            if confirming {
                return UIColor(red: 0.86, green: 0.85, blue: 0.92, alpha: 1)
            }
            return canAfford ? ShieldLook.indigoButton : ShieldLook.indigoMuted
        }

        var primaryForeground: UIColor {
            confirming ? ShieldLook.ink : .white
        }

        var secondaryForeground: UIColor {
            confirming ? ShieldLook.indigoButton : UIColor.white.withAlphaComponent(0.88)
        }
    }
}

private enum ShieldArtwork {
    static func seal(for state: ShieldLook.State) -> UIImage {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let disc = CGRect(origin: .zero, size: size).insetBy(dx: 20, dy: 20)

            cg.setShadow(
                offset: CGSize(width: 0, height: 8),
                blur: 18,
                color: UIColor.black.withAlphaComponent(state.confirming ? 0.16 : 0.35).cgColor
            )
            UIBezierPath(ovalIn: disc).fill()
            cg.setShadow(offset: .zero, blur: 0, color: nil)

            let top: UIColor
            let bottom: UIColor
            let symbolColor: UIColor
            if state.confirming {
                top = UIColor(red: 0.91, green: 0.90, blue: 0.99, alpha: 1)
                bottom = UIColor(red: 0.78, green: 0.76, blue: 0.96, alpha: 1)
                symbolColor = ShieldLook.indigo
            } else {
                top = UIColor(red: 0.46, green: 0.40, blue: 0.96, alpha: 1)
                bottom = UIColor(red: 0.28, green: 0.22, blue: 0.72, alpha: 1)
                symbolColor = .white
            }

            cg.saveGState()
            UIBezierPath(ovalIn: disc).addClip()
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [top.cgColor, bottom.cgColor] as CFArray,
                locations: [0, 1]
            ) {
                cg.drawLinearGradient(
                    gradient,
                    start: disc.origin,
                    end: CGPoint(x: disc.maxX, y: disc.maxY),
                    options: []
                )
            }
            cg.restoreGState()

            (state.confirming ? ShieldLook.indigo.withAlphaComponent(0.28) : UIColor.white.withAlphaComponent(0.28)).setStroke()
            let ring = UIBezierPath(ovalIn: disc.insetBy(dx: 6, dy: 6))
            ring.lineWidth = 3
            ring.stroke()

            let symbolName = state.confirming ? "key.fill" : "lock.fill"
            let config = UIImage.SymbolConfiguration(pointSize: state.confirming ? 80 : 86, weight: .bold)
            if let symbol = UIImage(systemName: symbolName, withConfiguration: config)?
                .withTintColor(symbolColor, renderingMode: .alwaysOriginal) {
                let symbolRect = CGRect(
                    x: (size.width - symbol.size.width) / 2,
                    y: (size.height - symbol.size.height) / 2,
                    width: symbol.size.width,
                    height: symbol.size.height
                )
                symbol.draw(in: symbolRect)
            }
        }
    }
}

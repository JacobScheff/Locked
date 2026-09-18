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
            backgroundBlurStyle: .systemChromeMaterialDark,
            backgroundColor: state.background,
            icon: ShieldArtwork.seal(for: state),
            title: .init(text: state.title, color: .white),
            subtitle: .init(text: state.subtitle, color: UIColor.white.withAlphaComponent(0.78)),
            primaryButtonLabel: .init(text: state.primaryTitle, color: state.primaryForeground),
            primaryButtonBackgroundColor: state.primaryBackground,
            secondaryButtonLabel: .init(text: state.secondaryTitle, color: UIColor.white.withAlphaComponent(0.92))
        )
    }
}

private struct ShieldLook {
    struct State {
        var confirming: Bool
        var canAfford: Bool
        var cost: Int
        var keys: Int

        var background: UIColor {
            if confirming {
                return UIColor(red: 0.18, green: 0.11, blue: 0.06, alpha: 0.94)
            }
            if canAfford {
                return UIColor(red: 0.08, green: 0.07, blue: 0.22, alpha: 0.94)
            }
            return UIColor(red: 0.09, green: 0.08, blue: 0.16, alpha: 0.94)
        }

        var title: String {
            if confirming { return "Spend \(cost) keys?" }
            return "This app is locked"
        }

        var subtitle: String {
            if confirming {
                let remaining = max(0, keys - cost)
                return "You’ll have \(remaining) left. It stays open until next Sunday."
            }
            if canAfford {
                return "\(cost) keys until Sunday · you have \(keys)"
            }
            return "Needs \(cost) keys · you have \(keys). Finish assignments in Locked to earn more."
        }

        var primaryTitle: String {
            if confirming { return "Confirm unlock" }
            if canAfford { return "Use keys" }
            return "Need \(cost) keys"
        }

        var secondaryTitle: String {
            confirming ? "Cancel" : "Keep locked"
        }

        var primaryBackground: UIColor {
            if confirming || canAfford {
                return UIColor(red: 0.97, green: 0.70, blue: 0.22, alpha: 1)
            }
            return UIColor(red: 0.28, green: 0.27, blue: 0.42, alpha: 1)
        }

        var primaryForeground: UIColor {
            if confirming || canAfford {
                return UIColor(red: 0.22, green: 0.12, blue: 0.02, alpha: 1)
            }
            return UIColor.white.withAlphaComponent(0.9)
        }
    }
}

private enum ShieldArtwork {
    static func seal(for state: ShieldLook.State) -> UIImage {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let canvas = CGRect(origin: .zero, size: size)
            let inset = canvas.insetBy(dx: 18, dy: 18)

            cg.setShadow(
                offset: CGSize(width: 0, height: 10),
                blur: 24,
                color: UIColor.black.withAlphaComponent(0.45).cgColor
            )

            let ring = UIBezierPath(ovalIn: inset)
            cg.setFillColor(UIColor.white.withAlphaComponent(0.14).cgColor)
            ring.fill()
            cg.setShadow(offset: .zero, blur: 0, color: nil)

            let disc = inset.insetBy(dx: 10, dy: 10)
            let colors: [CGColor]
            if state.confirming {
                colors = [
                    UIColor(red: 0.99, green: 0.82, blue: 0.38, alpha: 1).cgColor,
                    UIColor(red: 0.93, green: 0.52, blue: 0.14, alpha: 1).cgColor
                ]
            } else if state.canAfford {
                colors = [
                    UIColor(red: 0.48, green: 0.42, blue: 0.98, alpha: 1).cgColor,
                    UIColor(red: 0.24, green: 0.18, blue: 0.62, alpha: 1).cgColor
                ]
            } else {
                colors = [
                    UIColor(red: 0.32, green: 0.30, blue: 0.48, alpha: 1).cgColor,
                    UIColor(red: 0.16, green: 0.14, blue: 0.28, alpha: 1).cgColor
                ]
            }
            cg.saveGState()
            UIBezierPath(ovalIn: disc).addClip()
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
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

            UIColor.white.withAlphaComponent(0.22).setStroke()
            let innerRing = UIBezierPath(ovalIn: disc.insetBy(dx: 7, dy: 7))
            innerRing.lineWidth = 3
            innerRing.stroke()

            let symbolName = state.confirming ? "key.fill" : "lock.fill"
            let pointSize: CGFloat = state.confirming ? 78 : 84
            let symbolColor: UIColor = state.confirming
                ? UIColor(red: 0.22, green: 0.12, blue: 0.02, alpha: 1)
                : .white
            let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
            if let symbol = UIImage(systemName: symbolName, withConfiguration: config)?
                .withTintColor(symbolColor, renderingMode: .alwaysOriginal) {
                let symbolSize = symbol.size
                let symbolRect = CGRect(
                    x: (size.width - symbolSize.width) / 2,
                    y: (size.height - symbolSize.height) / 2 - (state.confirming ? 0 : 4),
                    width: symbolSize.width,
                    height: symbolSize.height
                )
                symbol.draw(in: symbolRect)
            }

            if !state.confirming, state.canAfford {
                let badge = CGRect(x: 158, y: 158, width: 72, height: 72)
                cg.setFillColor(UIColor(red: 0.97, green: 0.70, blue: 0.22, alpha: 1).cgColor)
                UIBezierPath(ovalIn: badge).fill()
                UIColor.white.withAlphaComponent(0.35).setStroke()
                let badgeStroke = UIBezierPath(ovalIn: badge.insetBy(dx: 1.5, dy: 1.5))
                badgeStroke.lineWidth = 2
                badgeStroke.stroke()
                let keyConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)
                if let key = UIImage(systemName: "key.fill", withConfiguration: keyConfig)?
                    .withTintColor(UIColor(red: 0.22, green: 0.12, blue: 0.02, alpha: 1), renderingMode: .alwaysOriginal) {
                    let keyRect = CGRect(
                        x: badge.midX - key.size.width / 2,
                        y: badge.midY - key.size.height / 2,
                        width: key.size.width,
                        height: key.size.height
                    )
                    key.draw(in: keyRect)
                }
            }
        }
    }
}

import FamilyControls
import ManagedSettings

class ShieldActionExtension: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(respond(to: action, token: application))
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        _ = webDomain
        completionHandler(action == .secondaryButtonPressed ? .close : .none)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        _ = category
        completionHandler(action == .secondaryButtonPressed ? .close : .none)
    }

    private func respond(to action: ShieldAction, token: ApplicationToken) -> ShieldActionResponse {
        switch action {
        case .primaryButtonPressed:
            return handlePrimary(token: token)
        case .secondaryButtonPressed:
            return handleSecondary(token: token)
        default:
            return .none
        }
    }

    /// Use keys arms confirmation. After that, this same control is Cancel
    /// so a double-tap cannot spend.
    private func handlePrimary(token: ApplicationToken) -> ShieldActionResponse {
        if ShieldUnlockPrompt.isConfirming(token) {
            ShieldUnlockPrompt.clear()
            return .defer
        }
        guard KeyUnlock.canAfford(token), LockedTokenStore.load().contains(token) else {
            return .defer
        }
        ShieldUnlockPrompt.begin(token)
        return .defer
    }

    /// Spend is only the secondary control, and only after Use keys.
    private func handleSecondary(token: ApplicationToken) -> ShieldActionResponse {
        guard ShieldUnlockPrompt.isConfirming(token) else {
            return .close
        }
        ShieldUnlockPrompt.clear()
        switch KeyUnlock.unlock(token: token) {
        case .unlocked:
            return .none
        case .notEnoughKeys, .notLocked:
            return .defer
        }
    }
}

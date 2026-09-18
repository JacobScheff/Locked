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
            if ShieldUnlockPrompt.isConfirming(token) {
                ShieldUnlockPrompt.clear()
                return .defer
            }
            return .close
        default:
            return .none
        }
    }

    private func handlePrimary(token: ApplicationToken) -> ShieldActionResponse {
        if ShieldUnlockPrompt.isConfirming(token) {
            guard ShieldUnlockPrompt.canConfirm(token) else {
                // Same finger is still on Use keys; wait for Confirm to show.
                return .none
            }
            ShieldUnlockPrompt.clear()
            switch KeyUnlock.unlock(token: token) {
            case .unlocked:
                return .none
            case .notEnoughKeys, .notLocked:
                return .defer
            }
        }

        guard KeyUnlock.canAfford(token), LockedTokenStore.load().contains(token) else {
            return .defer
        }
        ShieldUnlockPrompt.begin(token)
        return .defer
    }
}

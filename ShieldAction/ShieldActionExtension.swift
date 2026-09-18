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
            switch KeyUnlock.unlock(token: token) {
            case .unlocked:
                // Restriction is already gone. `.none` leaves the now-open
                // app in the foreground instead of bouncing to SpringBoard.
                return .none
            case .notEnoughKeys, .notLocked:
                return .defer
            }
        case .secondaryButtonPressed:
            return .close
        default:
            return .none
        }
    }
}

import Combine
#if !targetEnvironment(macCatalyst)
import DeviceActivity
import FamilyControls
#endif
import SwiftUI
import UIKit
import WidgetKit

@MainActor
final class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()

    @Published var authorizationStatus: AuthorizationStatus
    @Published var selection: FamilyActivitySelection {
        didSet {
            let expanded = ActivitySelectionStore.expandingCategories(selection)
            ActivitySelectionStore.save(expanded)
            LockedTokenStore.prune(to: expanded)
            UsageStore.syncLockedNames()
            ScreenTimeShields.sync()
        }
    }
    @Published var isPickerPresented = false
    @Published private(set) var isReady = false
    @Published private(set) var usageRevision = 0
    @Published private(set) var usageReportNonce = 0
    @Published private(set) var lastAuthorizationError: String?

    private var didStartDailyMonitor = false
    private var launchedAt = Date()
    private var isFinishingLaunch = false

    private init() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        selection = ActivitySelectionStore.load()
        observeUsageUpdates()
        Task { await beginLaunch() }
    }

    var isAuthorized: Bool {
        authorizationStatus == .approved
    }

    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    }

    var needsSetup: Bool {
        !isAuthorized || !hasSelection
    }

    var shouldCollectUsage: Bool {
        isAuthorized && hasSelection
    }

    var canUseFamilyControls: Bool {
        ScreenTimeAuthorizationAvailability.canRequest
    }

    var showsAuthorizationAction: Bool {
        isAuthorized || canUseFamilyControls
    }

    var setupCardTitle: String {
        if isAuthorized || canUseFamilyControls {
            return "Finish setup"
        }
        return "Screen Time needs iPhone or iPad"
    }

    var setupCardDetail: String {
        if isAuthorized {
            return "Choose the apps Locked is allowed to track and lock. Settings, Phone, and other safety apps stay out automatically."
        }
        if let blocked = ScreenTimeAuthorizationAvailability.blockedReason {
            return blocked
        }
        return "Allow Screen Time so Locked can track usage and lock apps for you."
    }

    var setupActionTitle: String {
        isAuthorized ? "Choose Apps" : "Allow Screen Time"
    }

    var unavailableSetupDetail: String {
        ScreenTimeAuthorizationAvailability.blockedReason
            ?? "Screen Time isn’t available on this device."
    }

    var reportDayKey: String {
        ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
    }

    func refreshStatus() {
        Economy.seedNewInstallIfNeeded()
        let status = AuthorizationCenter.shared.authorizationStatus
        if authorizationStatus != status {
            authorizationStatus = status
        }
        guard isAuthorized else { return }
        if !didStartDailyMonitor {
            ScreenTimeMonitor.startDaily()
            didStartDailyMonitor = true
        }
        checkAndPerformWeeklyLockIfNeeded()
        UsageStore.syncLockedNames()
        ScreenTimeShields.sync()
    }

    func handleSetupAction() async {
        if isAuthorized {
            presentPicker()
        } else {
            await requestAuthorization()
        }
    }

    func requestAuthorization() async {
        lastAuthorizationError = nil

        guard ScreenTimeAuthorizationAvailability.canRequest else {
            lastAuthorizationError = ScreenTimeAuthorizationAvailability.blockedReason
            refreshStatus()
            return
        }

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            lastAuthorizationError = ScreenTimeAuthorizationAvailability.userMessage(for: error)
            refreshStatus()
            return
        }

        refreshStatus()

        if !isAuthorized, lastAuthorizationError == nil {
            switch authorizationStatus {
            case .denied:
                lastAuthorizationError = "Screen Time access was denied. Enable Locked under Settings → Screen Time."
            case .notDetermined:
                lastAuthorizationError = "Apple didn’t show a Screen Time prompt. Try again, or check Settings → Screen Time."
            default:
                break
            }
        }
    }

    func presentPicker() {
        let expanded = ActivitySelectionStore.expandingCategories(selection)
        if !selection.includeEntireCategory {
            selection = expanded
        }
        isPickerPresented = true
    }

    func reloadUsageReport() {
        usageReportNonce += 1
    }

    func simulateWeeklyLock() {
        _ = performSundayLocking(using: selection, minimumLockCount: 1)
        reloadUsageReport()
        didStartDailyMonitor = false
        ScreenTimeMonitor.startDaily()
        didStartDailyMonitor = true
    }

    func noteUsageUpdated() {
        usageRevision += 1
        UsageStore.syncLockedNames()
        ScreenTimeShields.sync()
        WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
        markReady()
    }

    private func beginLaunch() async {
        // Let the launch overlay commit before Screen Time / shield work.
        await Task.yield()
        refreshStatus()
        markReady()
    }

    private func markReady() {
        guard !isReady, !isFinishingLaunch else { return }
        isFinishingLaunch = true
        // Keep the cover up just long enough to avoid a one-frame flash.
        let remaining = max(0, 0.12 - Date().timeIntervalSince(launchedAt))
        Task {
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            await Task.yield()
            withAnimation(.easeOut(duration: 0.28)) {
                isReady = true
            }
        }
    }

    private func observeUsageUpdates() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    ScreenTimeManager.shared.noteUsageUpdated()
                }
            },
            AppGroupStore.usageDidUpdateName as CFString,
            nil,
            .deliverImmediately
        )
    }
}

/// Family Controls authorization types are unavailable in Mac Catalyst and
/// never prompt in the Simulator. iPhone and iPad use the real API.
enum ScreenTimeAuthorizationAvailability {
    static var canRequest: Bool {
        #if targetEnvironment(macCatalyst) || targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    static var blockedReason: String? {
        #if targetEnvironment(macCatalyst)
        return "Apple doesn’t expose Screen Time authorization in Mac Catalyst. Use Locked on an iPhone or iPad to allow Screen Time and lock apps."
        #elseif targetEnvironment(simulator)
        return "Screen Time permission can’t be granted in the Simulator. Run Locked on an iPhone or iPad."
        #else
        return nil
        #endif
    }

    static func userMessage(for error: Error) -> String {
        if let familyError = error as? FamilyControlsError {
            switch familyError {
            case .unavailable:
                return "Screen Time authorization isn’t available on this device."
            case .restricted:
                return "Screen Time is restricted on this device, so Locked can’t be authorized."
            case .invalidAccountType:
                return "This Apple Account can’t authorize Screen Time for Locked."
            case .authorizationCanceled:
                return "Screen Time permission was canceled. Tap Allow Screen Time to try again."
            case .authorizationConflict:
                return "Another Screen Time controller is already active on this device."
            default:
                break
            }
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty {
            return description
        }
        return blockedReason ?? "Screen Time authorization failed. Try Allow Screen Time again."
    }
}

extension DeviceActivityReport.Context {
    static let usage = Self(LockedReportContext.name)
}

struct UsageReportHost: View {
    let selection: FamilyActivitySelection
    let dayKey: String
    var nonce: Int = 0

    private var identity: String {
        "\(dayKey)-\(nonce)-\(selection.applicationTokens.hashValue)-\(selection.categoryTokens.hashValue)"
    }

    var body: some View {
        HiddenUsageReport(filter: usageFilter(for: selection), identity: identity)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

/// DeviceActivityReport is a remote view. SwiftUI opacity/frame often do not
/// hide its system placeholder, so the hosting view is clipped and faded in UIKit.
private struct HiddenUsageReport: UIViewControllerRepresentable {
    var filter: DeviceActivityFilter
    var identity: String

    func makeCoordinator() -> Coordinator {
        Coordinator(identity: identity)
    }

    func makeUIViewController(context: Context) -> UIHostingController<HiddenUsageReportRoot> {
        let host = UIHostingController(rootView: HiddenUsageReportRoot(filter: filter))
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        host.view.clipsToBounds = true
        host.view.isUserInteractionEnabled = false
        host.view.alpha = 0.01
        host.view.frame = CGRect(x: -40, y: -40, width: 8, height: 8)
        return host
    }

    func updateUIViewController(_ uiViewController: UIHostingController<HiddenUsageReportRoot>, context: Context) {
        uiViewController.view.alpha = 0.01
        uiViewController.view.isUserInteractionEnabled = false
        guard context.coordinator.identity != identity else { return }
        context.coordinator.identity = identity
        uiViewController.rootView = HiddenUsageReportRoot(filter: filter)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: UIHostingController<HiddenUsageReportRoot>, context: Context) -> CGSize {
        .zero
    }

    final class Coordinator {
        var identity: String

        init(identity: String) {
            self.identity = identity
        }
    }
}

private struct HiddenUsageReportRoot: View {
    let filter: DeviceActivityFilter

    var body: some View {
        DeviceActivityReport(.usage, filter: filter)
            .frame(width: 8, height: 8)
    }
}

struct UnnamedLockedAppLabel: View {
    let app: UnnamedLockedApp

    var body: some View {
        Label(app.token)
            .labelStyle(.titleAndIcon)
    }
}

struct ManagedAppIcon: View {
    let name: String
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let token = UsageStore.token(for: name) {
                Label(token)
                    .labelStyle(.iconOnly)
                    .scaleEffect(size / 32)
            } else {
                AppIconView(appName: name)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

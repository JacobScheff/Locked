import Combine
import DeviceActivity
import FamilyControls
import SwiftUI
import UIKit

@MainActor
final class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()

    @Published var authorizationStatus: AuthorizationStatus
    @Published var selection: FamilyActivitySelection {
        didSet {
            ActivitySelectionStore.save(selection)
            ScreenTimeShields.sync(using: selection)
        }
    }
    @Published var isPickerPresented = false
    @Published private(set) var isReady = false
    @Published private(set) var usageRevision = 0

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

    var reportDayKey: String {
        ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
    }

    func refreshStatus() {
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
        ScreenTimeShields.sync(using: selection)
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            print("Screen Time authorization failed: \(error)")
        }
        refreshStatus()
    }

    func presentPicker() {
        isPickerPresented = true
    }

    func noteUsageUpdated() {
        usageRevision += 1
        ScreenTimeShields.sync(using: selection)
        markReady()
    }

    private func beginLaunch() async {
        refreshStatus()
        try? await Task.sleep(for: .milliseconds(160))
        refreshStatus()

        if !shouldCollectUsage {
            markReady()
            return
        }

        // Wait for the hidden report to finish (or time out) so the system
        // "Select apps to use Screen Time API" placeholder never appears.
        let timeout: TimeInterval = UsageStore.hasSnapshot ? 3 : 6
        try? await Task.sleep(for: .seconds(timeout))
        markReady()
    }

    private func markReady() {
        guard !isReady, !isFinishingLaunch else { return }
        isFinishingLaunch = true
        let remaining = max(0, 0.45 - Date().timeIntervalSince(launchedAt))
        Task {
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            withAnimation(.easeOut(duration: 0.32)) {
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

extension DeviceActivityReport.Context {
    static let usage = Self(LockedReportContext.name)
}

struct UsageReportHost: View {
    let selection: FamilyActivitySelection
    let dayKey: String

    private var identity: String {
        "\(dayKey)-\(selection.applicationTokens.hashValue)-\(selection.categoryTokens.hashValue)"
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

import Combine
import DeviceActivity
import FamilyControls
import SwiftUI

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

    private init() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        selection = ActivitySelectionStore.load()
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

    func refreshStatus() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        if isAuthorized {
            ScreenTimeMonitor.startDaily()
            checkAndPerformWeeklyLockIfNeeded()
            ScreenTimeShields.sync(using: selection)
        }
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
}

extension DeviceActivityReport.Context {
    static let usage = Self(LockedReportContext.name)
}

struct UsageReportHost: View {
    let selection: FamilyActivitySelection

    var body: some View {
        DeviceActivityReport(.usage, filter: usageFilter(for: selection))
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
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

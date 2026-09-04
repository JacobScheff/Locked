import DeviceActivity
import Foundation
import os.log

final class DeviceActivityMonitorExtension: DeviceActivity.DeviceActivityMonitor {
    private let logger = Logger(subsystem: "com.Jacob-Scheff.Locked", category: "Monitor")

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        logger.notice("intervalDidStart \(activity.rawValue, privacy: .public)")

        if activity == .daily {
            checkAndPerformWeeklyLockIfNeeded()
        }
        ScreenTimeShields.sync()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        logger.notice("intervalDidEnd \(activity.rawValue, privacy: .public)")

        if activity == .emergencyOverride {
            ScreenTimeShields.sync()
        }
    }
}

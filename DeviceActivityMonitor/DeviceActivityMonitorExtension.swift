import DeviceActivity
import Foundation
import os.log

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let logger = Logger(subsystem: "com.Jacob-Scheff.Locked", category: "Monitor")

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        logger.notice("intervalDidStart \(activity.rawValue, privacy: .public)")

        switch activity {
        case .daily:
            // Fires at midnight every day (and right after the app calls
            // startMonitoring), so this is what performs the weekly lock
            // when the app is closed and re-asserts shields each day.
            checkAndPerformWeeklyLockIfNeeded()
            UsageStore.syncLockedNames()
            ScreenTimeShields.sync()
        case .emergencyOverride:
            // The app already cleared shields; make sure a stale read of the
            // override flag never re-locks while the seal is broken.
            if EmergencyOverride.isActive() {
                ScreenTimeShields.clear()
            }
        default:
            ScreenTimeShields.sync()
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        logger.notice("intervalDidEnd \(activity.rawValue, privacy: .public)")

        if activity == .emergencyOverride {
            // The window is scheduled to end exactly at expiry. Clear the
            // stored expiry as well so a slightly early callback does not
            // leave the app and widget saying "released" with shields up.
            EmergencyOverride.setUntil(0)
            UsageStore.syncLockedNames()
            ScreenTimeShields.sync()
        }
    }
}

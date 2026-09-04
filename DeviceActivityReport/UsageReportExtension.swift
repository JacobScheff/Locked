import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

struct UsageSnapshot {
    var totalSeconds: Int
    var appCounts: [String: Int]
    var tokens: [String: Data]
}

struct UsageReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .usage
    let content: (UsageSnapshot) -> UsageReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> UsageSnapshot {
        var secondsByApp: [String: Int] = [:]
        var tokensByApp: [String: Data] = [:]

        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                for await category in segment.categories {
                    for await applicationActivity in category.applications {
                        let bundleID = applicationActivity.application.bundleIdentifier
                        let name = applicationActivity.application.localizedDisplayName
                            ?? bundleID
                            ?? "Unknown"
                        if ExcludedApps.isExcluded(bundleIdentifier: bundleID, displayName: name) {
                            continue
                        }

                        let seconds = Int(applicationActivity.totalActivityDuration.rounded())
                        secondsByApp[name, default: 0] += seconds
                        if let token = applicationActivity.application.token,
                           let tokenData = try? JSONEncoder().encode(token) {
                            tokensByApp[name] = tokenData
                        }
                    }
                }
            }
        }

        let snapshot = UsageSnapshot(
            totalSeconds: secondsByApp.values.reduce(0, +),
            appCounts: secondsByApp,
            tokens: tokensByApp
        )
        UsageStore.saveUsage(
            appCounts: snapshot.appCounts,
            tokens: snapshot.tokens,
            totalSeconds: snapshot.totalSeconds
        )
        return snapshot
    }
}

struct UsageReportView: View {
    let snapshot: UsageSnapshot

    var body: some View {
        Color.clear
            .accessibilityHidden(true)
    }
}

@main
struct UsageReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        UsageReport { snapshot in
            UsageReportView(snapshot: snapshot)
        }
    }
}

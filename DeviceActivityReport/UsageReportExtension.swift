import DeviceActivity
import ExtensionFoundation
import ExtensionKit
import FamilyControls
import ManagedSettings
import SwiftUI

extension DeviceActivityReport.Context {
    static let usage = Self(LockedReportContext.name)
}

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
        var bundleIDsByApp: [String: String] = [:]

        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                for await category in segment.categories {
                    for await applicationActivity in category.applications {
                        let bundleID = applicationActivity.application.bundleIdentifier
                        let rawName = applicationActivity.application.localizedDisplayName
                        let name = rawName?.trimmingCharacters(in: .whitespacesAndNewlines)
                        let seconds = Int(applicationActivity.totalActivityDuration.rounded())
                        guard seconds > 0,
                              InstalledApps.isPresent(bundleIdentifier: bundleID, displayName: name),
                              let name,
                              !ExcludedApps.isExcluded(bundleIdentifier: bundleID, displayName: name)
                        else {
                            continue
                        }

                        secondsByApp[name, default: 0] += seconds
                        if let bundleID {
                            bundleIDsByApp[name] = bundleID
                        }
                        let token = applicationActivity.application.token
                            ?? bundleID.flatMap { Application(bundleIdentifier: $0).token }
                        if let token, let tokenData = TokenCoding.encode(token) {
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
            bundleIDs: bundleIDsByApp
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

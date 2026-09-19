#if targetEnvironment(macCatalyst)
import Foundation
import SwiftUI

/// Apple marks Family Controls authorization types unavailable in Mac Catalyst.
/// These stand-ins let the Mac app compile. Screen Time locking stays on iPhone and iPad.

enum AuthorizationStatus: Equatable {
    case notDetermined
    case denied
    case approved
}

enum FamilyControlsMember {
    case individual
    case child
}

enum FamilyControlsError: Error {
    case unavailable
    case restricted
    case invalidAccountType
    case authorizationCanceled
    case authorizationConflict
}

struct ApplicationToken: Hashable, Codable {}
struct ActivityCategoryToken: Hashable, Codable {}
struct WebDomainToken: Hashable, Codable {}

struct FamilyActivitySelection: Hashable, Codable {
    var applicationTokens: Set<ApplicationToken> = []
    var categoryTokens: Set<ActivityCategoryToken> = []
    var webDomainTokens: Set<WebDomainToken> = []
    var includeEntireCategory: Bool

    init(includeEntireCategory: Bool = true) {
        self.includeEntireCategory = includeEntireCategory
    }
}

struct Application {
    var token: ApplicationToken?

    init(bundleIdentifier: String) {
        _ = bundleIdentifier
        token = nil
    }
}

final class AuthorizationCenter {
    static let shared = AuthorizationCenter()

    var authorizationStatus: AuthorizationStatus { .notDetermined }

    func requestAuthorization(for member: FamilyControlsMember) async throws {
        _ = member
        throw FamilyControlsError.unavailable
    }
}

struct ManagedSettingsStore {
    struct Name: Hashable {
        var rawValue: String

        init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }

    struct ShieldSettings {
        var applications: Set<ApplicationToken>?
        var applicationCategories: Set<ActivityCategoryToken>?
        var webDomains: Set<WebDomainToken>?
    }

    var shield = ShieldSettings()

    init() {}

    init(named: Name) {
        _ = named
    }
}

struct DeviceActivityName: Hashable {
    var rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

struct DeviceActivitySchedule {
    init(intervalStart: DateComponents, intervalEnd: DateComponents, repeats: Bool) {
        _ = (intervalStart, intervalEnd, repeats)
    }
}

final class DeviceActivityCenter {
    func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule) throws {
        _ = (activity, schedule)
    }

    func stopMonitoring(_ activities: [DeviceActivityName]) {
        _ = activities
    }
}

struct DeviceActivityFilter {
    struct Segment {
        static func daily(during interval: DateInterval) -> Segment {
            _ = interval
            return Segment()
        }
    }

    struct Users {
        static let all = Users()
    }

    struct Device: Hashable {
        static let iPhone = Device()
        static let iPad = Device()
    }

    struct Devices {
        init(_ devices: [Device]) {
            _ = devices
        }
    }

    init(
        segment: Segment,
        users: Users,
        devices: Devices,
        applications: Set<ApplicationToken> = [],
        categories: Set<ActivityCategoryToken> = []
    ) {
        _ = (segment, users, devices, applications, categories)
    }
}

struct DeviceActivityReport: View {
    struct Context {
        init(_ name: String) {
            _ = name
        }
    }

    init(_ context: Context, filter: DeviceActivityFilter) {
        _ = (context, filter)
    }

    var body: some View {
        Color.clear
    }
}

extension Label where Title == Text, Icon == Image {
    init(_ token: ApplicationToken) {
        _ = token
        self.init("App", systemImage: "square.grid.2x2.fill")
    }
}

extension View {
    func familyActivityPicker(
        isPresented: Binding<Bool>,
        selection: Binding<FamilyActivitySelection>
    ) -> some View {
        _ = (isPresented, selection)
        return self
    }
}
#endif

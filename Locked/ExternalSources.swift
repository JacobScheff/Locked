import Foundation
import Security
import WidgetKit

enum ExternalSourceProvider: String, Codable, CaseIterable, Identifiable {
    case gradescope
    case brightspace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gradescope: return "Gradescope"
        case .brightspace: return "Brightspace"
        }
    }

    var blurb: String {
        switch self {
        case .gradescope:
            return "Import your courses and keep due dates and submissions in sync."
        case .brightspace:
            return "D2L Brightspace is coming soon. You’ll connect it here the same way."
        }
    }

    var icon: String {
        switch self {
        case .gradescope: return "checkmark.rectangle.fill"
        case .brightspace: return "building.columns.fill"
        }
    }

    var isAvailable: Bool {
        switch self {
        case .gradescope: return true
        case .brightspace: return false
        }
    }
}

struct ExternalAssignmentSnapshot: Equatable {
    var remoteID: String
    var name: String
    var releaseDate: Date
    var dueDate: Date
    var submittedAt: Date?
    var pointsPossible: Double?
    var statusLabel: String
}

struct ExternalCourseSnapshot: Equatable {
    var remoteID: String
    var name: String
    var fullName: String?
    var termName: String?
    var assignments: [ExternalAssignmentSnapshot]
}

struct ExternalCatalogSnapshot: Equatable {
    var provider: ExternalSourceProvider
    var termNames: [String]
    var courses: [ExternalCourseSnapshot]
}

struct ExternalSyncReport: Equatable {
    var coursesCreated = 0
    var coursesUpdated = 0
    var assignmentsCreated = 0
    var assignmentsUpdated = 0
    var completionsAwarded = 0
    var keysAwarded: Double = 0
    var karmaDelta: Double = 0

    var summary: String {
        var parts: [String] = []
        if coursesCreated > 0 { parts.append("\(coursesCreated) new course\(coursesCreated == 1 ? "" : "s")") }
        if assignmentsCreated > 0 { parts.append("\(assignmentsCreated) new assignment\(assignmentsCreated == 1 ? "" : "s")") }
        if assignmentsUpdated > 0 { parts.append("\(assignmentsUpdated) updated") }
        if completionsAwarded > 0 {
            parts.append("\(completionsAwarded) submitted")
            let keys = Int(keysAwarded.rounded())
            if keys > 0 { parts.append("+\(keys) Keys") }
        }
        if parts.isEmpty { return "Everything is already up to date" }
        return parts.joined(separator: " · ")
    }
}

struct SourceConnectionState: Codable, Equatable {
    var email: String = ""
    var isConnected: Bool = false
    var lastSyncedAt: Date? = nil
    var lastTermName: String? = nil
    var lastSummary: String? = nil
    var lastError: String? = nil
    var courseCount: Int = 0
    var assignmentCount: Int = 0
}

enum SourceKeychain {
    static let service = "com.Jacob-Scheff.Locked.sources"

    static func account(for provider: ExternalSourceProvider, email: String) -> String {
        "\(provider.rawValue):\(email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    static func savePassword(_ password: String, provider: ExternalSourceProvider, email: String) throws {
        let account = account(for: provider, email: email)
        let data = Data(password.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SourceKeychainError.saveFailed
        }
    }

    static func password(provider: ExternalSourceProvider, email: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: provider, email: email),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deletePassword(provider: ExternalSourceProvider, email: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(for: provider, email: email),
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum SourceKeychainError: LocalizedError {
    case saveFailed

    var errorDescription: String? {
        "Couldn’t save your password on this iPhone."
    }
}

enum LMSDateParser {
    static func parse(_ raw: String?, termYear: Int? = nil, now: Date = .now) -> Date? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if let iso = isoDate(from: text) { return iso }
        if let spaced = posixDate(from: text, format: "yyyy-MM-dd HH:mm:ss Z") { return spaced }
        if let spacedNoZone = posixDate(from: text, format: "yyyy-MM-dd HH:mm:ss") { return spacedNoZone }
        if let compact = posixDate(from: text, format: "yyyy-MM-dd'T'HH:mm:ss") { return compact }
        if let short = posixDate(from: text, format: "yyyy-MM-dd'T'HH:mm") { return short }

        let year = termYear ?? Calendar.current.component(.year, from: now)
        let displayFormats = [
            "MMM d 'at' h:mma",
            "MMM dd 'at' h:mma",
            "MMM d 'at' hh:mma",
            "MMM dd 'at' hh:mma",
            "MMM d 'at' h:mm a",
            "MMM dd 'at' h:mm a",
        ]
        for format in displayFormats {
            if let date = posixDate(from: "\(text) \(year)", format: "\(format) yyyy") {
                return date
            }
        }
        return nil
    }

    private static func isoDate(from text: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: text) { return date }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withFractionalSeconds]
        return fractional.date(from: text)
    }

    private static func posixDate(from text: String, format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        formatter.dateFormat = format
        return formatter.date(from: text)
    }
}

extension CourseStore {
    /// Merge an LMS catalog into local courses. Newly submitted work is completed using
    /// the LMS submitted date — never the moment the user tapped Refresh.
    @discardableResult
    static func applyExternalCatalog(
        _ catalog: ExternalCatalogSnapshot,
        courses: inout [Course],
        keys: inout Double,
        karma: inout Double
    ) -> ExternalSyncReport {
        var report = ExternalSyncReport()
        let startingKeys = keys
        let startingKarma = karma

        for remoteCourse in catalog.courses {
            let courseIndex: Int
            if let existing = indexOfCourse(in: courses, matching: remoteCourse, provider: catalog.provider) {
                courseIndex = existing
                courses[courseIndex].sourceProvider = catalog.provider
                courses[courseIndex].sourceRemoteID = remoteCourse.remoteID
                report.coursesUpdated += 1
            } else {
                let course = Course(
                    name: remoteCourse.name,
                    accentIndex: CourseAccent.leastUsedIndex(in: courses),
                    sourceProvider: catalog.provider,
                    sourceRemoteID: remoteCourse.remoteID
                )
                courses.append(course)
                courseIndex = courses.count - 1
                report.coursesCreated += 1
            }

            for remote in remoteCourse.assignments {
                let assignmentIndex = indexOfAssignment(
                    in: courses[courseIndex].assignments,
                    matching: remote,
                    provider: catalog.provider
                )
                let wasCompleted: Bool
                var assignment: Assignment
                if let assignmentIndex {
                    assignment = courses[courseIndex].assignments[assignmentIndex]
                    wasCompleted = assignment.isCompleted
                    report.assignmentsUpdated += 1
                } else {
                    assignment = Assignment(
                        name: remote.name,
                        dueDate: remote.dueDate,
                        releaseDate: remote.releaseDate,
                        completionDate: nil,
                        pointsPossible: remote.pointsPossible,
                        sourceProvider: catalog.provider,
                        sourceRemoteID: remote.remoteID
                    )
                    wasCompleted = false
                    report.assignmentsCreated += 1
                }

                assignment.name = remote.name
                assignment.dueDate = remote.dueDate
                assignment.releaseDate = remote.releaseDate
                assignment.sourceProvider = catalog.provider
                assignment.sourceRemoteID = remote.remoteID
                if let points = remote.pointsPossible {
                    assignment.pointsPossible = points
                }

                if let submittedAt = remote.submittedAt, !wasCompleted {
                    assignment.completionDate = submittedAt
                    karma = clampKarma(karma + assignment.karmaReward(ifCompletedAt: submittedAt))
                    keys = clampKeys(keys + assignment.keysReward)
                    report.completionsAwarded += 1
                }

                if let assignmentIndex {
                    courses[courseIndex].assignments[assignmentIndex] = assignment
                } else {
                    courses[courseIndex].assignments.append(assignment)
                }
            }
        }

        report.keysAwarded = keys - startingKeys
        report.karmaDelta = karma - startingKarma
        if report.completionsAwarded > 0 {
            Economy.setKarma(karma)
            Economy.setKeys(keys)
            WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
        }
        return report
    }

    private static func indexOfCourse(
        in courses: [Course],
        matching remote: ExternalCourseSnapshot,
        provider: ExternalSourceProvider
    ) -> Int? {
        if let index = courses.firstIndex(where: {
            $0.sourceProvider == provider && $0.sourceRemoteID == remote.remoteID
        }) {
            return index
        }

        let target = remote.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return courses.firstIndex { course in
            guard course.sourceRemoteID == nil else { return false }
            return course.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target
        }
    }

    private static func indexOfAssignment(
        in assignments: [Assignment],
        matching remote: ExternalAssignmentSnapshot,
        provider: ExternalSourceProvider
    ) -> Int? {
        if let index = assignments.firstIndex(where: {
            $0.sourceProvider == provider && $0.sourceRemoteID == remote.remoteID
        }) {
            return index
        }

        let target = remote.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return assignments.firstIndex { assignment in
            guard assignment.sourceRemoteID == nil else { return false }
            return assignment.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target
        }
    }
}

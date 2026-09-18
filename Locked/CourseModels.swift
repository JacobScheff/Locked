import SwiftUI
import WidgetKit

// MARK: - Models

struct Assignment: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var dueDate: Date
    var releaseDate: Date
    var completionDate: Date?
    var pointsPossible: Double?

    var isCompleted: Bool { completionDate != nil }
    var isOverdue: Bool { !isCompleted && dueDate < Date.now }

    var statusColor: Color {
        if isCompleted { return .lockedTeal }
        if isOverdue { return .lockedRose }
        return .lockedIndigo
    }

    static func blank(dueInDays: Int = 7) -> Assignment {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let day = calendar.date(byAdding: .day, value: dueInDays, to: start) ?? .now
        let due = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: day) ?? day
        return Assignment(
            name: "",
            dueDate: due,
            releaseDate: .now,
            completionDate: nil,
            pointsPossible: nil
        )
    }

    var keysReward: Double {
        10.0 + (pointsPossible ?? 0)
    }

    func karmaReward(ifCompletedAt date: Date = .now) -> Double {
        calculateKarmaDelta(releaseDate: releaseDate, dueDate: dueDate, completionDate: date)
    }

    func karmaFinishPreview(currentKarma: Double, ifCompletedAt date: Date = .now) -> KarmaFinishPreview {
        KarmaFinishPreview(delta: karmaReward(ifCompletedAt: date), currentKarma: currentKarma)
    }
}

enum KarmaFinishPreview: Equatable {
    case gain(Int)
    case loss(Int)
    case floorsToZero
    case unchanged

    init(delta: Double, currentKarma: Double) {
        if abs(delta) < 0.5 {
            self = .unchanged
        } else if delta >= 0 {
            self = .gain(Int(delta.rounded()))
        } else if currentKarma + delta <= 0 {
            self = .floorsToZero
        } else {
            self = .loss(Int((-delta).rounded()))
        }
    }

    var confirmationText: String {
        switch self {
        case .gain(let amount):
            return "about +\(amount) Karma"
        case .loss(let amount):
            return "about −\(amount) Karma"
        case .floorsToZero:
            return "sets karma to 0"
        case .unchanged:
            return "Karma unchanged"
        }
    }
}

struct Course: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var assignments: [Assignment] = []
    var accentIndex: Int? = nil

    var completionPercentage: Double {
        guard !assignments.isEmpty else { return 0 }
        return Double(completedCount) / Double(assignments.count)
    }

    var completedCount: Int { assignments.filter(\.isCompleted).count }
    var overdueCount: Int { assignments.filter(\.isOverdue).count }
    var openCount: Int { assignments.filter { !$0.isCompleted }.count }

    var nextDueAssignment: Assignment? {
        assignments.filter { !$0.isCompleted }.sorted { $0.dueDate < $1.dueDate }.first
    }

    var accent: Color { CourseAccent.color(for: name, index: accentIndex) }
}

struct UpcomingWork: Identifiable {
    var id: UUID { assignment.id }
    let course: Course
    let assignment: Assignment

    var group: AssignmentDueGroup {
        AssignmentDueGroup.group(for: assignment.dueDate)
    }
}

enum AssignmentDueGroup: Int, CaseIterable, Identifiable {
    case overdue, today, tomorrow, thisWeek, later

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .overdue: return "Overdue"
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .thisWeek: return "This week"
        case .later: return "Later"
        }
    }

    var icon: String {
        switch self {
        case .overdue: return "exclamationmark.circle.fill"
        case .today: return "sun.max.fill"
        case .tomorrow: return "sunrise.fill"
        case .thisWeek: return "calendar"
        case .later: return "clock.fill"
        }
    }

    var tint: Color {
        switch self {
        case .overdue: return .lockedRose
        case .today: return .lockedIndigo
        case .tomorrow: return .lockedViolet
        case .thisWeek: return .lockedTeal
        case .later: return .secondary
        }
    }

    static func group(for date: Date, now: Date = .now) -> AssignmentDueGroup {
        if date < now { return .overdue }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return .today }
        if calendar.isDateInTomorrow(date) { return .tomorrow }
        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return .thisWeek
        }
        return .later
    }
}

enum CourseStore {
    static func upcoming(from courses: [Course]) -> [UpcomingWork] {
        courses.flatMap { course in
            course.assignments
                .filter { !$0.isCompleted }
                .map { UpcomingWork(course: course, assignment: $0) }
        }
        .sorted { $0.assignment.dueDate < $1.assignment.dueDate }
    }

    static func groupedUpcoming(from courses: [Course]) -> [(group: AssignmentDueGroup, items: [UpcomingWork])] {
        let items = upcoming(from: courses)
        return AssignmentDueGroup.allCases.compactMap { group in
            let slice = items.filter { $0.group == group }
            return slice.isEmpty ? nil : (group, slice)
        }
    }

    static func totals(from courses: [Course]) -> (open: Int, overdue: Int, completed: Int) {
        let assignments = courses.flatMap(\.assignments)
        return (
            assignments.filter { !$0.isCompleted }.count,
            assignments.filter(\.isOverdue).count,
            assignments.filter(\.isCompleted).count
        )
    }

    @discardableResult
    static func saveAssignment(
        _ savedAssignment: Assignment,
        to courseID: UUID,
        movingFrom previousCourseID: UUID? = nil,
        courses: inout [Course],
        keys: inout Double,
        karma: inout Double
    ) -> Bool {
        if let previousCourseID, previousCourseID != courseID,
           let oldIndex = courses.firstIndex(where: { $0.id == previousCourseID }) {
            courses[oldIndex].assignments.removeAll { $0.id == savedAssignment.id }
        }

        guard let courseIndex = courses.firstIndex(where: { $0.id == courseID }) else { return false }

        let assignmentIndex = courses[courseIndex].assignments.firstIndex(where: { $0.id == savedAssignment.id })
        let wasCompleted = assignmentIndex.map { courses[courseIndex].assignments[$0].isCompleted } ?? false
        var awarded = false

        if !wasCompleted && savedAssignment.isCompleted {
            karma = clampKarma(karma + savedAssignment.karmaReward(ifCompletedAt: savedAssignment.completionDate ?? .now))
            keys = clampKeys(keys + savedAssignment.keysReward)
            Economy.setKarma(karma)
            Economy.setKeys(keys)
            WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
            awarded = true
        }

        withAnimation {
            if let assignmentIndex {
                courses[courseIndex].assignments[assignmentIndex] = savedAssignment
            } else {
                courses[courseIndex].assignments.append(savedAssignment)
            }
        }

        return awarded
    }
}

enum AssignmentDueCopy {
    static func caption(for date: Date, now: Date = .now, completed: Bool = false) -> String {
        if completed { return "Completed" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        if date < now {
            return "Overdue \(formatter.localizedString(for: date, relativeTo: now))"
        }
        return "Due \(formatter.localizedString(for: date, relativeTo: now))"
    }

    static func short(for date: Date, now: Date = .now) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }

    static func countdown(for date: Date, now: Date = .now) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        let overdue = seconds < 0
        let elapsed = abs(seconds)
        let days = elapsed / 86_400
        let hours = (elapsed % 86_400) / 3_600
        let minutes = (elapsed % 3_600) / 60

        let core: String
        if days > 0 {
            core = hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        } else if hours > 0 {
            core = "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            core = "\(minutes)m"
        } else {
            core = overdue ? "just now" : "<1m"
        }

        if overdue { return core == "just now" ? "Just overdue" : "\(core) overdue" }
        return core
    }
}

struct AssignmentComposer: Identifiable {
    var id: UUID { assignment.id }
    var courseID: UUID
    var assignment: Assignment
    var allowsCourseSwitch: Bool
    var isNew: Bool
}

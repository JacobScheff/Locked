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
    var sourceProvider: ExternalSourceProvider? = nil
    var sourceRemoteID: String? = nil
    var isHidden: Bool? = nil
    var rewardsApplied: Bool? = nil

    var isCompleted: Bool { completionDate != nil }
    var isOverdue: Bool { !isCompleted && dueDate < Date.now }
    var isFromSource: Bool { sourceRemoteID != nil }
    var isHiddenFromApp: Bool { isHidden == true }

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
    var sourceProvider: ExternalSourceProvider? = nil
    var sourceRemoteID: String? = nil
    var isHidden: Bool? = nil

    var isFromSource: Bool { sourceRemoteID != nil }
    var isHiddenFromApp: Bool { isHidden == true }

    var visibleAssignments: [Assignment] {
        guard !isHiddenFromApp else { return [] }
        return assignments.filter { !$0.isHiddenFromApp }
    }

    var completionPercentage: Double {
        let visible = visibleAssignments
        guard !visible.isEmpty else { return 0 }
        return Double(visible.filter(\.isCompleted).count) / Double(visible.count)
    }

    var completedCount: Int { visibleAssignments.filter(\.isCompleted).count }
    var overdueCount: Int { visibleAssignments.filter(\.isOverdue).count }
    var openCount: Int { visibleAssignments.filter { !$0.isCompleted }.count }

    var nextDueAssignment: Assignment? {
        visibleAssignments.filter { !$0.isCompleted }.sorted { $0.dueDate < $1.dueDate }.first
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
    static func visibleCourses(from courses: [Course]) -> [Course] {
        courses.filter { !$0.isHiddenFromApp }
    }

    static func hiddenCourseCount(in courses: [Course]) -> Int {
        courses.filter(\.isHiddenFromApp).count
    }

    static func hiddenAssignmentCount(in courses: [Course]) -> Int {
        courses.filter { !$0.isHiddenFromApp }.reduce(0) { $0 + $1.assignments.filter(\.isHiddenFromApp).count }
    }

    static func upcoming(from courses: [Course]) -> [UpcomingWork] {
        visibleCourses(from: courses).flatMap { course in
            course.visibleAssignments
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
        let assignments = visibleCourses(from: courses).flatMap(\.visibleAssignments)
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
        var assignment = savedAssignment
        let suppressed = courses[courseIndex].isHiddenFromApp || assignment.isHiddenFromApp

        if !wasCompleted && assignment.isCompleted {
            if suppressed {
                assignment.rewardsApplied = false
            } else {
                karma = clampKarma(karma + assignment.karmaReward(ifCompletedAt: assignment.completionDate ?? .now))
                keys = clampKeys(keys + assignment.keysReward)
                assignment.rewardsApplied = true
                Economy.setKarma(karma)
                Economy.setKeys(keys)
                WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
                awarded = true
            }
        }

        withAnimation {
            if let assignmentIndex {
                courses[courseIndex].assignments[assignmentIndex] = assignment
            } else {
                courses[courseIndex].assignments.append(assignment)
            }
        }

        return awarded
    }

    static func setCourseHidden(
        _ courseID: UUID,
        hidden: Bool,
        courses: inout [Course],
        keys: inout Double,
        karma: inout Double
    ) {
        guard let index = courses.firstIndex(where: { $0.id == courseID }) else { return }
        withAnimation {
            courses[index].isHidden = hidden
        }
        if !hidden {
            applyDeferredRewards(in: &courses[index], keys: &keys, karma: &karma)
        }
    }

    static func setAssignmentHidden(
        _ assignmentID: UUID,
        in courseID: UUID,
        hidden: Bool,
        courses: inout [Course],
        keys: inout Double,
        karma: inout Double
    ) {
        guard let courseIndex = courses.firstIndex(where: { $0.id == courseID }),
              let assignmentIndex = courses[courseIndex].assignments.firstIndex(where: { $0.id == assignmentID })
        else { return }
        withAnimation {
            courses[courseIndex].assignments[assignmentIndex].isHidden = hidden
        }
        if !hidden {
            applyDeferredRewards(
                for: &courses[courseIndex].assignments[assignmentIndex],
                courseHidden: courses[courseIndex].isHiddenFromApp,
                keys: &keys,
                karma: &karma
            )
        }
    }

    private static func applyDeferredRewards(
        in course: inout Course,
        keys: inout Double,
        karma: inout Double
    ) {
        guard !course.isHiddenFromApp else { return }
        for index in course.assignments.indices {
            applyDeferredRewards(
                for: &course.assignments[index],
                courseHidden: false,
                keys: &keys,
                karma: &karma
            )
        }
    }

    private static func applyDeferredRewards(
        for assignment: inout Assignment,
        courseHidden: Bool,
        keys: inout Double,
        karma: inout Double
    ) {
        guard !courseHidden,
              !assignment.isHiddenFromApp,
              assignment.isCompleted,
              assignment.rewardsApplied != true
        else { return }
        karma = clampKarma(karma + assignment.karmaReward(ifCompletedAt: assignment.completionDate ?? .now))
        keys = clampKeys(keys + assignment.keysReward)
        assignment.rewardsApplied = true
        Economy.setKarma(karma)
        Economy.setKeys(keys)
        WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
    }

    static func deleteCourse(_ courseID: UUID, courses: inout [Course]) {
        withAnimation {
            courses.removeAll { $0.id == courseID }
        }
    }

    static func deleteAllHiddenCourses(from courses: inout [Course]) {
        withAnimation {
            courses.removeAll { $0.isHiddenFromApp }
        }
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

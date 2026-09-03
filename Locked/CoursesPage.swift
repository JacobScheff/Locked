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
}

struct Course: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var assignments: [Assignment] = []

    var completionPercentage: Double {
        guard !assignments.isEmpty else { return 0 }
        let completed = assignments.filter { $0.isCompleted }.count
        return Double(completed) / Double(assignments.count)
    }

    var completedCount: Int { assignments.filter { $0.isCompleted }.count }
    var overdueCount: Int { assignments.filter { $0.isOverdue }.count }

    var nextDueAssignment: Assignment? {
        assignments.filter { !$0.isCompleted }.sorted { $0.dueDate < $1.dueDate }.first
    }
}

// MARK: - Courses Page

struct CoursesPage: View {
    @AppStorage("courses", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var courses: [Course] = []

    @State private var editingCourse: Course?
    @State private var courseToDelete: Course?

    private var upcoming: [(course: Course, assignment: Assignment)] {
        courses.flatMap { course in
            course.assignments.filter { !$0.isCompleted }.map { (course, $0) }
        }
        .sorted { $0.assignment.dueDate < $1.assignment.dueDate }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if courses.isEmpty {
                    emptyState
                } else {
                    if !upcoming.isEmpty {
                        upcomingSection
                    }
                    coursesSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(LockedBackground())
        .navigationTitle("Courses")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingCourse = Course(name: "")
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(LockedTheme.karmaGradient)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Add course")
            }
        }
        .sheet(item: $editingCourse) { course in
            CourseEditorView(course: course) { savedCourse in
                withAnimation {
                    if let index = courses.firstIndex(where: { $0.id == savedCourse.id }) {
                        courses[index] = savedCourse
                    } else {
                        courses.append(savedCourse)
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete \"\(courseToDelete?.name ?? "Course")\"?",
            isPresented: Binding(
                get: { courseToDelete != nil },
                set: { if !$0 { courseToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let course = courseToDelete {
                    withAnimation {
                        courses.removeAll { $0.id == course.id }
                    }
                }
                courseToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                courseToDelete = nil
            }
        } message: {
            Text("All assignments in this course will also be deleted.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 44))
                .foregroundStyle(LockedTheme.karmaGradient)
                .padding(.top, 48)

            Text("No courses yet")
                .font(.lockedTitle(24))

            Text("Add a class, then log assignments. Finishing them early earns Keys and Karma — that’s what keeps your apps unlocked.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Button {
                editingCourse = Course(name: "")
            } label: {
                Label("Add a course", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(LockedTheme.karmaGradient)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LockedSectionLabel(title: "Up next", icon: "clock.fill")

            VStack(spacing: 8) {
                ForEach(Array(upcoming.prefix(4)), id: \.assignment.id) { item in
                    NavigationLink {
                        CourseDetailView(courses: $courses, courseID: item.course.id)
                    } label: {
                        UpcomingAssignmentCard(course: item.course, assignment: item.assignment)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LockedSectionLabel(title: "Your courses", icon: "book.fill")

            VStack(spacing: 12) {
                ForEach(courses) { course in
                    CourseCardView(
                        courses: $courses,
                        course: course,
                        onRename: { editingCourse = course },
                        onDelete: { courseToDelete = course }
                    )
                }
            }
        }
    }
}

// MARK: - Course cards

private struct UpcomingAssignmentCard: View {
    let course: Course
    let assignment: Assignment

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(assignment.dueDate.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(assignment.isOverdue ? Color.lockedRose : Color.lockedIndigo)
                Text(assignment.dueDate.formatted(.dateTime.day()))
                    .font(.lockedNumber(20))
                    .foregroundStyle(assignment.isOverdue ? Color.lockedRose : .primary)
            }
            .frame(width: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(assignment.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(course.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if assignment.isOverdue {
                Text("Overdue")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.lockedRose)
                    .clipShape(Capsule())
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(LockedCardBackground(cornerRadius: 18))
    }
}

struct CourseCardView: View {
    @Binding var courses: [Course]
    let course: Course
    var onRename: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                CourseDetailView(courses: $courses, courseID: course.id)
            } label: {
                cardBody
            }
            .buttonStyle(.plain)

            Menu {
                Button(action: onRename) {
                    Label("Rename", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .padding(.top, 10)
            .padding(.trailing, 10)
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    ProgressRing(
                        progress: course.completionPercentage,
                        lineWidth: 5,
                        gradient: LinearGradient(
                            colors: [courseAccent(course.name), courseAccent(course.name).opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    Text("\(Int(course.completionPercentage * 100))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(course.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 28)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(courseAccent(course.name).gradient)
                        .frame(width: max(geo.size.width * course.completionPercentage, course.assignments.isEmpty ? 0 : 4))
                }
            }
            .frame(height: 6)

            if let next = course.nextDueAssignment {
                HStack(spacing: 6) {
                    Image(systemName: next.isOverdue ? "exclamationmark.circle.fill" : "calendar")
                        .foregroundStyle(next.isOverdue ? Color.lockedRose : .secondary)
                    Text("Next: \(next.name)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(next.dueDate.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(next.isOverdue ? Color.lockedRose : .secondary)
                }
                .font(.caption.weight(.medium))
            }
        }
        .padding(18)
        .background(LockedCardBackground())
    }

    private var subtitle: String {
        let count = course.assignments.count
        if count == 0 { return "No assignments yet" }
        var parts = ["\(course.completedCount)/\(count) done"]
        if course.overdueCount > 0 {
            parts.append("\(course.overdueCount) overdue")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Course Detail

struct CourseDetailView: View {
    @Binding var courses: [Course]
    let courseID: UUID

    @AppStorage("keys", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked")) var keys: Double = 0.0
    @AppStorage("karma", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked")) var karma: Double = 0.0

    @State private var editingAssignment: Assignment?
    @State private var assignmentToDelete: Assignment?
    @State private var assignmentToComplete: Assignment?
    @State private var assignmentToUncomplete: Assignment?

    private var courseIndex: Int? { courses.firstIndex { $0.id == courseID } }
    private var course: Course? { courseIndex != nil ? courses[courseIndex!] : nil }

    private var pendingAssignments: [Assignment] {
        course?.assignments.filter { !$0.isCompleted }.sorted { $0.dueDate < $1.dueDate } ?? []
    }

    private var completedAssignments: [Assignment] {
        course?.assignments.filter { $0.isCompleted }.sorted { $0.completionDate ?? .now > $1.completionDate ?? .now } ?? []
    }

    var body: some View {
        Group {
            if let course {
                List {
                    Section {
                        CourseProgressHeader(course: course)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if course.assignments.isEmpty {
                        Section {
                            emptyAssignments
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        if !pendingAssignments.isEmpty {
                            Section("To do") {
                                ForEach(pendingAssignments) { assignment in
                                    AssignmentRowView(
                                        assignment: assignment,
                                        onToggle: { assignmentToComplete = assignment },
                                        onOpen: { editingAssignment = assignment }
                                    )
                                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .swipeActions(edge: .leading) {
                                        Button { assignmentToComplete = assignment } label: {
                                            Label("Complete", systemImage: "checkmark")
                                        }
                                        .tint(.lockedTeal)
                                    }
                                    .swipeActions(edge: .trailing) { deleteAndEditActions(for: assignment) }
                                }
                            }
                        }

                        if !completedAssignments.isEmpty {
                            Section("Completed") {
                                ForEach(completedAssignments) { assignment in
                                    AssignmentRowView(
                                        assignment: assignment,
                                        onToggle: { assignmentToUncomplete = assignment },
                                        onOpen: { editingAssignment = assignment }
                                    )
                                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .swipeActions(edge: .leading) {
                                        Button { assignmentToUncomplete = assignment } label: {
                                            Label("Mark Pending", systemImage: "arrow.uturn.backward")
                                        }
                                        .tint(.orange)
                                    }
                                    .swipeActions(edge: .trailing) { deleteAndEditActions(for: assignment) }
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .listSectionSpacing(14)
                .animation(.default, value: course.assignments)
            }
        }
        .background(LockedBackground())
        .navigationTitle(course?.name ?? "Course")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Button {
                editingAssignment = Assignment(
                    name: "",
                    dueDate: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now,
                    releaseDate: .now,
                    completionDate: nil,
                    pointsPossible: nil
                )
            } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(LockedTheme.karmaGradient)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Add assignment")
        }
        .sheet(item: $editingAssignment) { assignment in
            AssignmentEditorView(assignment: assignment) { savedAssignment in
                saveAssignment(savedAssignment)
            }
        }
        .confirmationDialog(
            "Delete \"\(assignmentToDelete?.name ?? "Assignment")\"?",
            isPresented: Binding(
                get: { assignmentToDelete != nil },
                set: { if !$0 { assignmentToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let assignment = assignmentToDelete {
                    withAnimation {
                        courses[courseIndex!].assignments.removeAll { $0.id == assignment.id }
                    }
                }
                assignmentToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                assignmentToDelete = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .confirmationDialog(
            "Mark \"\(assignmentToComplete?.name ?? "Assignment")\" as completed?",
            isPresented: Binding(
                get: { assignmentToComplete != nil },
                set: { if !$0 { assignmentToComplete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Mark as Completed") {
                if let assignment = assignmentToComplete {
                    markCompleted(assignment)
                }
                assignmentToComplete = nil
            }
            Button("Cancel", role: .cancel) {
                assignmentToComplete = nil
            }
        } message: {
            Text("You’ll earn Keys, and Karma based on how early you finished.")
        }
        .confirmationDialog(
            "Mark \"\(assignmentToUncomplete?.name ?? "Assignment")\" as pending?",
            isPresented: Binding(
                get: { assignmentToUncomplete != nil },
                set: { if !$0 { assignmentToUncomplete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Mark as Pending") {
                if let assignment = assignmentToUncomplete {
                    markIncomplete(assignment)
                }
                assignmentToUncomplete = nil
            }
            Button("Cancel", role: .cancel) {
                assignmentToUncomplete = nil
            }
        }
    }

    private var emptyAssignments: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.badge.plus")
                .font(.title)
                .foregroundStyle(Color.lockedIndigo)
            Text("No assignments")
                .font(.headline)
            Text("Add work to earn Keys and Karma when you finish it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: Actions

    @ViewBuilder
    private func deleteAndEditActions(for assignment: Assignment) -> some View {
        Button {
            assignmentToDelete = assignment
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .tint(.red)

        Button {
            editingAssignment = assignment
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        .tint(.orange)
    }

    private func saveAssignment(_ savedAssignment: Assignment) {
        guard let courseIndex else { return }

        let assignmentIndex = courses[courseIndex].assignments.firstIndex(where: { $0.id == savedAssignment.id })
        let wasCompleted = assignmentIndex != nil ? courses[courseIndex].assignments[assignmentIndex!].isCompleted : false

        if !wasCompleted && savedAssignment.isCompleted {
            let karmaDelta = calculateKarmaDelta(
                releaseDate: savedAssignment.releaseDate,
                dueDate: savedAssignment.dueDate,
                completionDate: savedAssignment.completionDate ?? .now
            )
            karma += karmaDelta

            if karma < 0 {
                karma = 0
            } else if karma > 100 {
                karma = 100
            }

            let baseKeys = 10.0
            let pointBonus = savedAssignment.pointsPossible ?? 0.0
            keys += (baseKeys + pointBonus)
            WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
        }

        withAnimation {
            if let index = assignmentIndex {
                courses[courseIndex].assignments[index] = savedAssignment
            } else {
                courses[courseIndex].assignments.append(savedAssignment)
            }
        }
    }

    private func markCompleted(_ assignment: Assignment) {
        var updated = assignment
        updated.completionDate = .now
        saveAssignment(updated)
    }

    private func markIncomplete(_ assignment: Assignment) {
        var updated = assignment
        updated.completionDate = nil
        saveAssignment(updated)
    }
}

private struct CourseProgressHeader: View {
    let course: Course

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                ProgressRing(
                    progress: course.completionPercentage,
                    lineWidth: 8,
                    gradient: LinearGradient(
                        colors: [courseAccent(course.name), .lockedIndigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                VStack(spacing: -2) {
                    Text("\(Int(course.completionPercentage * 100))")
                        .font(.lockedNumber(22))
                    Text("%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 76, height: 76)

            HStack(spacing: 10) {
                MiniStat(value: "\(course.assignments.filter { !$0.isCompleted }.count)", label: "Open")
                MiniStat(value: "\(course.completedCount)", label: "Done")
                MiniStat(
                    value: "\(course.overdueCount)",
                    label: "Late",
                    emphasize: course.overdueCount > 0
                )
            }
        }
        .padding(18)
        .background(LockedCardBackground())
    }
}

private struct MiniStat: View {
    let value: String
    let label: String
    var emphasize = false

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.lockedNumber(20))
                .foregroundStyle(emphasize ? Color.lockedRose : .primary)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Assignment Row View

struct AssignmentRowView: View {
    let assignment: Assignment
    var onToggle: () -> Void
    var onOpen: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: assignment.isCompleted ? "checkmark.circle.fill" : (assignment.isOverdue ? "exclamationmark.circle.fill" : "circle"))
                    .font(.title2)
                    .foregroundStyle(assignment.statusColor)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(assignment.isCompleted ? "Mark as pending" : "Mark as completed")

            Button(action: onOpen) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(assignment.name)
                            .font(.body.weight(.semibold))
                            .strikethrough(assignment.isCompleted)
                            .foregroundStyle(assignment.isCompleted ? Color.secondary : Color.primary)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text(assignment.dueDate.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(assignment.isOverdue ? Color.lockedRose : Color.secondary)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let points = assignment.pointsPossible {
                        VStack(spacing: 0) {
                            Text("\(points, specifier: "%.0f")")
                                .font(.subheadline.weight(.bold))
                            Text("pts")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(LockedCardBackground(cornerRadius: 16))
    }
}

// MARK: - Course Editor

struct CourseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    let course: Course
    let onSave: (Course) -> Void

    @State private var name: String

    init(course: Course, onSave: @escaping (Course) -> Void) {
        self.course = course
        self.onSave = onSave
        _name = State(initialValue: course.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Computer Science 101", text: $name)
                        .focused($isFocused)
                } header: {
                    Text("Course Name")
                } footer: {
                    Text("Completing this course’s assignments earns Keys and Karma.")
                }
            }
            .navigationTitle(course.name.isEmpty ? "New Course" : "Rename Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let saved = Course(id: course.id, name: cleaned, assignments: course.assignments)
                        onSave(saved)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
        .presentationDetents([.medium])
        .tint(.lockedIndigo)
    }
}

// MARK: - Assignment Editor

struct AssignmentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    let assignment: Assignment
    let onSave: (Assignment) -> Void

    @State private var name: String
    @State private var dueDate: Date
    @State private var releaseDate: Date
    @State private var isCompleted: Bool
    @State private var completionDate: Date
    @State private var pointsText: String

    enum Field { case name, points }

    init(assignment: Assignment, onSave: @escaping (Assignment) -> Void) {
        self.assignment = assignment
        self.onSave = onSave

        _name = State(initialValue: assignment.name)
        _dueDate = State(initialValue: assignment.dueDate)
        _releaseDate = State(initialValue: assignment.releaseDate)
        _isCompleted = State(initialValue: assignment.completionDate != nil)
        _completionDate = State(initialValue: assignment.completionDate ?? .now)
        _pointsText = State(initialValue: assignment.pointsPossible.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Assignment Name", text: $name)
                        .focused($focusedField, equals: .name)

                    TextField("Points / Grade Weight (Optional)", text: $pointsText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .points)
                }

                Section("Dates") {
                    DatePicker("Assigned", selection: $releaseDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                        .foregroundStyle(dueDate < Date.now && !isCompleted ? Color.lockedRose : Color.primary)
                }

                Section {
                    Toggle("Mark as Completed", isOn: $isCompleted.animation())
                        .tint(.lockedTeal)

                    if isCompleted {
                        DatePicker("Completed", selection: $completionDate, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                    }
                } header: {
                    Text("Status")
                } footer: {
                    Text("Finishing early grants more Karma. Keys are based on the point value, plus a base reward.")
                }
            }
            .navigationTitle(assignment.name.isEmpty ? "New Assignment" : "Edit Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let points = Double(pointsText.trimmingCharacters(in: .whitespacesAndNewlines))

                        let saved = Assignment(
                            id: assignment.id,
                            name: cleaned,
                            dueDate: dueDate,
                            releaseDate: releaseDate,
                            completionDate: isCompleted ? completionDate : nil,
                            pointsPossible: points
                        )

                        onSave(saved)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                if assignment.name.isEmpty {
                    focusedField = .name
                }
            }
        }
        .tint(.lockedIndigo)
    }
}

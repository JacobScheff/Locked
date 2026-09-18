import SwiftUI

struct CoursesPage: View {
    @AppStorage("courses", store: .lockedGroup)
    var courses: [Course] = []

    @AppStorage("keys", store: .lockedGroup) var keys: Double = 0.0
    @AppStorage("karma", store: .lockedGroup) var karma: Double = 0.0

    @State private var editingCourse: Course?
    @State private var courseToDelete: Course?
    @State private var composer: AssignmentComposer?

    private var totals: (open: Int, overdue: Int, completed: Int) {
        CourseStore.totals(from: courses)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if courses.isEmpty {
                    emptyState
                } else {
                    workloadHero
                    UpcomingPreviewSection(courses: $courses, limit: 4)
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
                Menu {
                    Button {
                        editingCourse = Course(name: "")
                    } label: {
                        Label("New course", systemImage: "book.fill")
                    }
                    if !courses.isEmpty {
                        Button {
                            composer = AssignmentComposer(
                                courseID: courses[0].id,
                                assignment: .blank(),
                                allowsCourseSwitch: courses.count > 1,
                                isNew: true
                            )
                        } label: {
                            Label("New assignment", systemImage: "checkmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(LockedTheme.karmaGradient)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Add")
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
        .sheet(item: $composer) { draft in
            AssignmentEditorView(
                assignment: draft.assignment,
                courseID: draft.courseID,
                courseOptions: draft.allowsCourseSwitch ? courses : [],
                onSave: { courseID, saved in
                    _ = CourseStore.saveAssignment(
                        saved,
                        to: courseID,
                        movingFrom: draft.isNew ? nil : draft.courseID,
                        courses: &courses,
                        keys: &keys,
                        karma: &karma
                    )
                }
            )
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

            Text("Build your semester")
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

    private var workloadHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workloadHeadline)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(workloadDetail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
            }

            HStack(spacing: 10) {
                WorkloadMetric(value: "\(totals.open)", label: "Open", color: .white)
                WorkloadMetric(value: "\(totals.overdue)", label: "Overdue", color: totals.overdue > 0 ? .lockedRose : .white)
                WorkloadMetric(value: "\(totals.completed)", label: "Done", color: .lockedTeal)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LockedTheme.heroGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: Color.lockedIndigo.opacity(0.28), radius: 20, x: 0, y: 10)
        }
    }

    private var workloadHeadline: String {
        if totals.open == 0 { return "You're all caught up" }
        if totals.overdue > 0 { return "Catch up, then get ahead" }
        if let next = CourseStore.upcoming(from: courses).first {
            return "Next: \(next.assignment.name)"
        }
        return "\(totals.open) still open"
    }

    private var workloadDetail: String {
        if totals.open == 0 {
            return "No open assignments. Add work to keep earning Keys and Karma."
        }
        if totals.overdue > 0 {
            return "\(totals.overdue) overdue · \(totals.open) still open"
        }
        return "\(totals.open) open · finishing early earns more Karma"
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
                        onDelete: { courseToDelete = course },
                        onAddAssignment: {
                            composer = AssignmentComposer(
                                courseID: course.id,
                                assignment: .blank(),
                                allowsCourseSwitch: false,
                                isNew: true
                            )
                        }
                    )
                }
            }
        }
    }
}

private struct WorkloadMetric: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.lockedNumber(22))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct CourseCardView: View {
    @Binding var courses: [Course]
    let course: Course
    var onRename: () -> Void = {}
    var onDelete: () -> Void = {}
    var onAddAssignment: () -> Void = {}

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                CourseDetailView(courses: $courses, courseID: course.id)
            } label: {
                cardBody
            }
            .buttonStyle(.plain)

            Menu {
                Button(action: onAddAssignment) {
                    Label("Add assignment", systemImage: "plus.circle")
                }
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
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    ProgressRing(
                        progress: course.completionPercentage,
                        lineWidth: 6,
                        gradient: LinearGradient(
                            colors: [course.accent, course.accent.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    Text("\(Int(course.completionPercentage * 100))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 28)
            }

            if let next = course.nextDueAssignment {
                HStack(spacing: 8) {
                    Image(systemName: next.isOverdue ? "exclamationmark.circle.fill" : "calendar")
                        .foregroundStyle(next.isOverdue ? Color.lockedRose : course.accent)
                    Text(next.name)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text(AssignmentDueCopy.short(for: next.dueDate))
                        .foregroundStyle(next.isOverdue ? Color.lockedRose : .secondary)
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(course.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .padding(.leading, 6)
        .background(LockedCardBackground())
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: LockedTheme.cardRadius,
                bottomLeadingRadius: LockedTheme.cardRadius,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(course.accent)
            .frame(width: 6)
        }
    }

    private var subtitle: String {
        let count = course.assignments.count
        if count == 0 { return "No assignments yet" }
        var parts = ["\(course.completedCount)/\(count) done"]
        if course.overdueCount > 0 {
            parts.append("\(course.overdueCount) overdue")
        } else if course.openCount > 0 {
            parts.append("\(course.openCount) open")
        }
        return parts.joined(separator: " · ")
    }
}

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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Course name")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("e.g. Computer Science 101", text: $name)
                            .font(.title3.weight(.semibold))
                            .focused($isFocused)
                            .padding(16)
                            .background(LockedCardBackground(cornerRadius: 16))
                    }

                    HStack(spacing: 10) {
                        Circle()
                            .fill(courseAccent(name.isEmpty ? "Course" : name))
                            .frame(width: 14, height: 14)
                        Text("This color is based on the course name.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LockedCardBackground(cornerRadius: 16))

                    Text("Completing this course’s assignments earns Keys and Karma.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(LockedBackground())
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
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium])
        .tint(.lockedIndigo)
    }
}

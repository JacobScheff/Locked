import SwiftUI
import UIKit

struct HomeCoursesSection: View {
    @Binding var courses: [Course]
    @Binding var keys: Double
    @Binding var karma: Double

    var refresh: () async -> Void

    @EnvironmentObject private var sources: ExternalSourceController
    @State private var editingCourse: Course?
    @State private var courseToHide: Course?

    private var visibleCourses: [Course] {
        CourseStore.visibleCourses(from: courses)
    }

    private var totals: (open: Int, overdue: Int, completed: Int) {
        CourseStore.totals(from: courses)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if !visibleCourses.isEmpty {
                CompactWorkloadBar(
                    open: totals.open,
                    overdue: totals.overdue,
                    completed: totals.completed
                )
                UpcomingPreviewSection(courses: $courses, limit: 3)
            }

            coursesSection
        }
        .sheet(item: $editingCourse) { course in
            CourseEditorView(course: course) { savedCourse in
                withAnimation {
                    if let index = courses.firstIndex(where: { $0.id == savedCourse.id }) {
                        courses[index] = savedCourse
                    }
                }
            }
        }
        .confirmationDialog(
            "Hide \"\(courseToHide?.name ?? "Course")\"?",
            isPresented: Binding(
                get: { courseToHide != nil },
                set: { if !$0 { courseToHide = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Hide") {
                if let course = courseToHide {
                    CourseStore.setCourseHidden(
                        course.id,
                        hidden: true,
                        courses: &courses,
                        keys: &keys,
                        karma: &karma
                    )
                }
                courseToHide = nil
            }
            Button("Cancel", role: .cancel) {
                courseToHide = nil
            }
        } message: {
            Text("It won’t show in Locked or count toward Keys and Karma until you unhide it.")
        }
    }

    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            coursesHeader

            if visibleCourses.isEmpty {
                emptyState
            } else {
                VStack(spacing: 12) {
                    ForEach(visibleCourses) { course in
                        CourseCardView(
                            courses: $courses,
                            course: course,
                            onRename: { editingCourse = course },
                            onHide: { courseToHide = course }
                        )
                    }
                }
            }
        }
    }

    private var coursesHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "book.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Your courses")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)

            NavigationLink {
                SourcesPage(courses: $courses, keys: $keys, karma: $karma)
            } label: {
                courseHeaderButton {
                    Image(systemName: "link")
                        .font(.subheadline.weight(.bold))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sources")

            Spacer(minLength: 12)

            if sources.canRefresh {
                Button {
                    Task { await refresh() }
                } label: {
                    courseHeaderButton {
                        SpinningSyncIcon(
                            spinning: sources.isRefreshing,
                            color: .lockedIndigo,
                            font: .subheadline.weight(.bold)
                        )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(sources.isRefreshing ? "Refreshing sources" : "Refresh sources")
                .allowsHitTesting(!sources.isRefreshing)
            }
        }
    }

    private func courseHeaderButton<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .foregroundStyle(Color.lockedIndigo)
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.lockedIndigo.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.lockedIndigo.opacity(0.22), lineWidth: 1)
            )
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 34))
                .foregroundStyle(LockedTheme.karmaGradient)

            Text("Connect your semester")
                .font(.lockedTitle(20))

            Text("Load classes from Gradescope or Brightspace. Finishing early earns Keys and Karma.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            NavigationLink {
                SourcesPage(courses: $courses, keys: $keys, karma: $karma)
            } label: {
                Label(sources.canRefresh ? "Open sources" : "Connect a source", systemImage: "link")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(LockedTheme.karmaGradient)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(LockedCardBackground())
    }
}

struct CompactWorkloadBar: View {
    let open: Int
    let overdue: Int
    let completed: Int

    var body: some View {
        VStack(spacing: 6) {
            Text("Assignments")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.7))
                .textCase(.uppercase)
                .tracking(0.7)

            HStack(spacing: 0) {
                metric("\(open)", "Open", .white)
                metric("\(overdue)", "Overdue", overdue > 0 ? Color.lockedRose : .white)
                metric("\(completed)", "Done", .lockedTeal)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LockedTheme.heroGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: Color.lockedIndigo.opacity(0.22), radius: 12, x: 0, y: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(open) open assignments, \(overdue) overdue, \(completed) done")
    }

    private func metric(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.lockedNumber(18))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity)
    }
}

struct CourseCardView: View {
    @Binding var courses: [Course]
    let course: Course
    var onRename: () -> Void = {}
    var onHide: () -> Void = {}

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
                Button(action: onHide) {
                    Label("Hide", systemImage: "eye.slash")
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
                        gradient: course.accent.gradient
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
        let count = course.visibleAssignments.count
        if count == 0 { return "No assignments yet" }
        var parts = ["\(course.completedCount)/\(count) done"]
        if course.overdueCount > 0 {
            parts.append("\(course.overdueCount) overdue")
        } else if course.openCount > 0 {
            parts.append("\(course.openCount) open")
        }
        if let provider = course.sourceProvider {
            parts.append(provider.title)
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
    @State private var accentIndex: Int

    init(course: Course, onSave: @escaping (Course) -> Void) {
        self.course = course
        self.onSave = onSave
        _name = State(initialValue: course.name)
        if let index = course.accentIndex, CourseAccent.palette.indices.contains(index) {
            _accentIndex = State(initialValue: index)
        } else if course.name.isEmpty {
            _accentIndex = State(initialValue: CourseAccent.leastUsedIndex(in: []))
        } else {
            _accentIndex = State(initialValue: CourseAccent.hashIndex(for: course.name))
        }
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

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        CourseColorPicker(selectedIndex: $accentIndex)
                        Text("Tap a color to change it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
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
                        let saved = Course(
                            id: course.id,
                            name: cleaned,
                            assignments: course.assignments,
                            accentIndex: accentIndex,
                            sourceProvider: course.sourceProvider,
                            sourceRemoteID: course.sourceRemoteID,
                            isHidden: course.isHidden
                        )
                        onSave(saved)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium, .large])
        .tint(.lockedIndigo)
    }
}

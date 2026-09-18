import SwiftUI

struct HiddenWorkView: View {
    @Binding var courses: [Course]
    @Binding var keys: Double
    @Binding var karma: Double

    private var hiddenCourses: [Course] {
        courses.filter(\.isHiddenFromApp).sorted { $0.name < $1.name }
    }

    private var hiddenAssignments: [(course: Course, assignment: Assignment)] {
        courses
            .filter { !$0.isHiddenFromApp }
            .flatMap { course in
                course.assignments
                    .filter(\.isHiddenFromApp)
                    .map { (course, $0) }
            }
            .sorted { $0.assignment.name < $1.assignment.name }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Archived work stays out of upcoming lists and doesn’t earn Keys and Karma until you unhide it. Permanently delete archived classes in Settings. Refreshing a linked source will import a deleted class again if it’s still there.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if hiddenCourses.isEmpty && hiddenAssignments.isEmpty {
                    emptyState
                } else {
                    if !hiddenCourses.isEmpty {
                        section(title: "Courses", icon: "book.fill") {
                            ForEach(hiddenCourses) { course in
                                hiddenRow(
                                    title: course.name,
                                    detail: "\(course.assignments.count) assignment\(course.assignments.count == 1 ? "" : "s")",
                                    accent: course.accent
                                ) {
                                    CourseStore.setCourseHidden(
                                        course.id,
                                        hidden: false,
                                        courses: &courses,
                                        keys: &keys,
                                        karma: &karma
                                    )
                                }
                            }
                        }
                    }

                    if !hiddenAssignments.isEmpty {
                        section(title: "Assignments", icon: "checkmark.circle") {
                            ForEach(hiddenAssignments, id: \.assignment.id) { item in
                                hiddenRow(
                                    title: item.assignment.name,
                                    detail: item.course.name,
                                    accent: item.course.accent
                                ) {
                                    CourseStore.setAssignmentHidden(
                                        item.assignment.id,
                                        in: item.course.id,
                                        hidden: false,
                                        courses: &courses,
                                        keys: &keys,
                                        karma: &karma
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(LockedBackground())
        .navigationTitle("Archived")
        .navigationBarTitleDisplayMode(.large)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "eye")
                .font(.system(size: 34))
                .foregroundStyle(Color.lockedIndigo)
            Text("Nothing hidden")
                .font(.headline)
            Text("Hide a course or assignment from its menu when you don’t want it counted. Delete archived classes forever in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func section<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LockedSectionLabel(title: title, icon: icon)
            VStack(spacing: 10) {
                content()
            }
        }
    }

    private func hiddenRow(title: String, detail: String, accent: Color, onUnhide: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(accent)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Unhide", action: onUnhide)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(.lockedIndigo)
        }
        .padding(14)
        .background(LockedCardBackground(cornerRadius: 16))
    }
}

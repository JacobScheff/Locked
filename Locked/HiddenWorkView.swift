import SwiftUI

struct HiddenWorkView: View {
    @Binding var courses: [Course]
    @Binding var keys: Double
    @Binding var karma: Double

    @State private var courseToDelete: Course?
    @State private var confirmDeleteAll = false

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
                Text("Archived work stays out of upcoming lists and doesn’t earn Keys and Karma until you unhide it. Deleting a class is permanent on this iPhone. Refreshing a linked source will import it again if it’s still listed there.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if hiddenCourses.isEmpty && hiddenAssignments.isEmpty {
                    emptyState
                } else {
                    if !hiddenCourses.isEmpty {
                        section(title: "Courses", icon: "book.fill") {
                            ForEach(hiddenCourses) { course in
                                archivedCourseRow(course)
                            }
                        }

                        Button {
                            confirmDeleteAll = true
                        } label: {
                            Label("Delete all archived classes", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .tint(.lockedRose)
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
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Delete \"\(courseToDelete?.name ?? "class")\" forever?",
            isPresented: Binding(
                get: { courseToDelete != nil },
                set: { if !$0 { courseToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete forever", role: .destructive) {
                if let course = courseToDelete {
                    CourseStore.deleteCourse(course.id, courses: &courses)
                }
                courseToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                courseToDelete = nil
            }
        } message: {
            Text("This removes it from Locked. Refreshing a linked source will import it again if it’s still in that source.")
        }
        .confirmationDialog(
            "Delete all archived classes forever?",
            isPresented: $confirmDeleteAll,
            titleVisibility: .visible
        ) {
            Button("Delete all", role: .destructive) {
                CourseStore.deleteAllHiddenCourses(from: &courses)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Refreshing a linked source will bring back any class that’s still listed there.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "archivebox")
                .font(.system(size: 34))
                .foregroundStyle(Color.lockedIndigo)
            Text("Nothing archived")
                .font(.headline)
            Text("Hide a course or assignment from its menu when you don’t want it counted.")
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

    private func archivedCourseRow(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(course.accent)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(course.name)
                        .font(.subheadline.weight(.semibold))
                    Text("\(course.assignments.count) assignment\(course.assignments.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    CourseStore.setCourseHidden(
                        course.id,
                        hidden: false,
                        courses: &courses,
                        keys: &keys,
                        karma: &karma
                    )
                } label: {
                    Text("Unhide")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.lockedIndigo)

                Button(role: .destructive) {
                    courseToDelete = course
                } label: {
                    Text("Delete")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(LockedCardBackground(cornerRadius: 16))
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

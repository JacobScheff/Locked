import SwiftUI
import WidgetKit

struct SettingsPage: View {
    @EnvironmentObject private var screenTime: ScreenTimeManager

    @AppStorage("courses", store: .lockedGroup)
    var courses: [Course] = []

    @AppStorage("keys", store: .lockedGroup) var keys: Double = 0.0
    @AppStorage("karma", store: .lockedGroup) var karma: Double = 0.0

    @State private var courseToDelete: Course?
    @State private var confirmDeleteAll = false

    private var archivedCourses: [Course] {
        courses.filter(\.isHiddenFromApp).sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                intro
                archivedSection
                developerSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(LockedBackground())
        .navigationTitle("Settings")
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

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Locked options")
                .font(.lockedTitle(26))
            Text("Archive classes to keep them out of the app. Delete them here if you want them gone until the next source refresh.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LockedSectionLabel(title: "Archived classes", icon: "archivebox.fill")

            Text("Hidden courses live here. Deleting is permanent on this iPhone. If the class is still in Gradescope’s current term, the next refresh will load it again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if archivedCourses.isEmpty {
                LockedCard {
                    Text("No archived classes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(archivedCourses) { course in
                        archivedRow(course)
                    }
                }

                Button {
                    confirmDeleteAll = true
                } label: {
                    Label("Delete all archived", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.lockedRose)
            }
        }
    }

    private func archivedRow(_ course: Course) -> some View {
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

    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LockedSectionLabel(title: "Developer", icon: "hammer.fill")
            Button {
                screenTime.simulateWeeklyLock()
                WidgetCenter.shared.reloadTimelines(ofKind: "Locked_Widget")
            } label: {
                Label("Simulate weekly lock", systemImage: "lock.rotation")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.lockedRose)
            Text("Locks at least one managed app using Screen Time tokens, then refreshes usage so remaining names get their shields.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

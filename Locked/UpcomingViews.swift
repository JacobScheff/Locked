import SwiftUI

struct UpcomingAssignmentsView: View {
    @Binding var courses: [Course]
    var title: String = "Upcoming"

    private var grouped: [(group: AssignmentDueGroup, items: [UpcomingWork])] {
        CourseStore.groupedUpcoming(from: courses)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if grouped.isEmpty {
                    emptyState
                } else {
                    ForEach(grouped, id: \.group) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            LockedSectionLabel(title: section.group.title, icon: section.group.icon)
                            VStack(spacing: 10) {
                                ForEach(section.items) { item in
                                    NavigationLink {
                                        AssignmentDetailView(
                                            courses: $courses,
                                            courseID: item.course.id,
                                            assignmentID: item.assignment.id
                                        )
                                    } label: {
                                        UpcomingWorkCard(item: item, showsCourse: true)
                                    }
                                    .buttonStyle(.plain)
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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 42))
                .foregroundStyle(Color.lockedTeal)
                .padding(.top, 40)
            Text("Nothing due")
                .font(.lockedTitle(24))
            Text("Finished work earns Keys and Karma. Add an assignment to start the loop.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
}

struct UpcomingWorkCard: View {
    let item: UpcomingWork
    var showsCourse = true

    var body: some View {
        HStack(spacing: 14) {
            dueBadge

            VStack(alignment: .leading, spacing: 4) {
                Text(item.assignment.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if showsCourse {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(item.course.accent)
                            .frame(width: 7, height: 7)
                        Text(item.course.name)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(item.assignment.dueDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(AssignmentDueCopy.countdown(for: item.assignment.dueDate, now: context.date))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(item.assignment.isOverdue ? Color.lockedRose : Color.secondary)
                        .multilineTextAlignment(.trailing)
                }

                if item.assignment.isOverdue {
                    LockedStatusPill(text: "Overdue", color: .lockedRose, filled: true)
                } else if item.group == .today {
                    LockedStatusPill(text: "Today", color: .lockedIndigo)
                } else if let provider = item.assignment.sourceProvider {
                    LockedStatusPill(text: provider.title, color: .lockedIndigo)
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            item.assignment.isOverdue ? Color.lockedRose.opacity(0.35) : Color.primary.opacity(0.05),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 6)
        }
        .accessibilityElement(children: .combine)
    }

    private var dueBadge: some View {
        VStack(spacing: 2) {
            Text(item.assignment.dueDate.formatted(.dateTime.month(.abbreviated)))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(item.assignment.isOverdue ? Color.lockedRose : item.course.accent)
            Text(item.assignment.dueDate.formatted(.dateTime.day()))
                .font(.lockedNumber(22))
                .foregroundStyle(item.assignment.isOverdue ? Color.lockedRose : .primary)
        }
        .frame(width: 48)
        .padding(.vertical, 8)
        .background(
            (item.assignment.isOverdue ? Color.lockedRose : item.course.accent).opacity(0.12)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct UpcomingPreviewSection: View {
    @Binding var courses: [Course]
    var limit: Int = 4

    private var items: [UpcomingWork] {
        Array(CourseStore.upcoming(from: courses).prefix(limit))
    }

    private var remaining: Int {
        max(0, CourseStore.upcoming(from: courses).count - items.count)
    }

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                LockedSectionLabel(title: "Up next", icon: "calendar") {
                    NavigationLink {
                        UpcomingAssignmentsView(courses: $courses)
                    } label: {
                        Text(remaining > 0 ? "See all +\(remaining)" : "See all")
                            .font(.caption.weight(.semibold))
                    }
                }

                VStack(spacing: 10) {
                    ForEach(items) { item in
                        NavigationLink {
                            AssignmentDetailView(
                                courses: $courses,
                                courseID: item.course.id,
                                assignmentID: item.assignment.id
                            )
                        } label: {
                            UpcomingWorkCard(item: item, showsCourse: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

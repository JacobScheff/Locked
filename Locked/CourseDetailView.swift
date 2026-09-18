import SwiftUI

struct CourseDetailView: View {
    @Binding var courses: [Course]
    let courseID: UUID

    @Environment(\.dismiss) private var dismiss
    @AppStorage("keys", store: .lockedGroup) var keys: Double = 0.0
    @AppStorage("karma", store: .lockedGroup) var karma: Double = 0.0

    @State private var presentedSheet: CourseDetailSheet?
    @State private var assignmentToHide: Assignment?
    @State private var assignmentToComplete: Assignment?
    @State private var assignmentToUncomplete: Assignment?
    @State private var confirmHideCourse = false
    @State private var filter: Filter = .open

    private enum CourseDetailSheet: Identifiable {
        case composer(AssignmentComposer)
        case color

        var id: String {
            switch self {
            case .composer(let draft):
                return "composer-\(draft.id.uuidString)"
            case .color:
                return "color"
            }
        }
    }

    enum Filter: String, CaseIterable, Identifiable {
        case open = "To do"
        case done = "Completed"
        var id: String { rawValue }
    }

    private var courseIndex: Int? { courses.firstIndex { $0.id == courseID } }
    private var course: Course? { courseIndex.map { courses[$0] } }

    private var pendingAssignments: [Assignment] {
        course?.visibleAssignments.filter { !$0.isCompleted }.sorted { $0.dueDate < $1.dueDate } ?? []
    }

    private var completedAssignments: [Assignment] {
        course?.visibleAssignments
            .filter(\.isCompleted)
            .sorted { $0.completionDate ?? .now > $1.completionDate ?? .now } ?? []
    }

    private var visibleAssignments: [Assignment] {
        filter == .open ? pendingAssignments : completedAssignments
    }

    private var accentBinding: Binding<Int> {
        Binding(
            get: {
                guard let course else { return CourseAccent.automaticIndices.first ?? 0 }
                return CourseAccent.resolvedIndex(for: course)
            },
            set: { newValue in
                guard let courseIndex else { return }
                withAnimation {
                    courses[courseIndex].accentIndex = newValue
                }
            }
        )
    }

    var body: some View {
        Group {
            if let course {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        CourseProgressHeader(course: course)

                        if !course.visibleAssignments.isEmpty {
                            Picker("Filter", selection: $filter) {
                                ForEach(Filter.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        if course.visibleAssignments.isEmpty {
                            emptyAssignments
                        } else if visibleAssignments.isEmpty {
                            filterEmpty
                        } else {
                            VStack(spacing: 10) {
                                ForEach(visibleAssignments) { assignment in
                                    HStack(alignment: .center, spacing: 10) {
                                        Button {
                                            if assignment.isCompleted {
                                                assignmentToUncomplete = assignment
                                            } else {
                                                assignmentToComplete = assignment
                                            }
                                        } label: {
                                            Image(systemName: assignment.isCompleted ? "checkmark.circle.fill" : (assignment.isOverdue ? "exclamationmark.circle.fill" : "circle"))
                                                .font(.title2)
                                                .foregroundStyle(assignment.statusColor)
                                                .symbolRenderingMode(.hierarchical)
                                                .frame(width: 36, height: 44)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(assignment.isCompleted ? "Mark as pending" : "Mark as completed")

                                        NavigationLink {
                                            AssignmentDetailView(
                                                courses: $courses,
                                                courseID: courseID,
                                                assignmentID: assignment.id
                                            )
                                        } label: {
                                            AssignmentRowView(assignment: assignment)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.leading, 10)
                                    .padding(.trailing, 14)
                                    .padding(.vertical, 10)
                                    .background(LockedCardBackground(cornerRadius: 16))
                                    .contextMenu {
                                        Button {
                                            presentedSheet = .composer(
                                                AssignmentComposer(
                                                    courseID: courseID,
                                                    assignment: assignment,
                                                    allowsCourseSwitch: false,
                                                    isNew: false
                                                )
                                            )
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        Button {
                                            assignmentToHide = assignment
                                        } label: {
                                            Label("Hide", systemImage: "eye.slash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(LockedBackground())
        .navigationTitle(course?.name ?? "Course")
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if course != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        presentedSheet = .color
                    } label: {
                        Image(systemName: "paintpalette")
                    }
                    .accessibilityLabel("Change course color")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        confirmHideCourse = true
                    } label: {
                        Image(systemName: "eye.slash")
                    }
                    .accessibilityLabel("Hide course")
                }
            }
        }
        .confirmationDialog(
            "Hide \"\(course?.name ?? "Course")\"?",
            isPresented: $confirmHideCourse,
            titleVisibility: .visible
        ) {
            Button("Hide") {
                if let course {
                    CourseStore.setCourseHidden(
                        course.id,
                        hidden: true,
                        courses: &courses,
                        keys: &keys,
                        karma: &karma
                    )
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It won’t show in Locked or count toward Keys and Karma until you unhide it.")
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .composer(let draft):
                AssignmentEditorView(
                    assignment: draft.assignment,
                    courseID: draft.courseID,
                    courseOptions: [],
                    onSave: { _, saved in
                        save(saved)
                    }
                )
            case .color:
                CourseColorPickerSheet(
                    courseName: course?.name ?? "Course",
                    selectedIndex: accentBinding
                )
            }
        }
        .confirmationDialog(
            "Hide \"\(assignmentToHide?.name ?? "Assignment")\"?",
            isPresented: Binding(
                get: { assignmentToHide != nil },
                set: { if !$0 { assignmentToHide = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Hide") {
                if let assignment = assignmentToHide {
                    CourseStore.setAssignmentHidden(
                        assignment.id,
                        in: courseID,
                        hidden: true,
                        courses: &courses,
                        keys: &keys,
                        karma: &karma
                    )
                }
                assignmentToHide = nil
            }
            Button("Cancel", role: .cancel) {
                assignmentToHide = nil
            }
        } message: {
            Text("It won’t show in Locked or count toward Keys and Karma until you unhide it.")
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
            Text(completeMessage)
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

    private var completeMessage: String {
        guard let assignment = assignmentToComplete else {
            return "You’ll earn Keys, and Karma based on how early you finished."
        }
        let keysGain = Int(assignment.keysReward)
        let preview = assignment.karmaFinishPreview(currentKarma: karma)
        switch preview {
        case .gain, .loss, .unchanged:
            return "You’ll earn \(keysGain) Keys and \(preview.confirmationText)."
        case .floorsToZero:
            return "You’ll earn \(keysGain) Keys. Sets karma to 0."
        }
    }

    private var emptyAssignments: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 34))
                .foregroundStyle(course?.accent ?? Color.lockedIndigo)
            Text("No assignments")
                .font(.headline)
            Text("Refresh your source to load assignments for this course.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .background(LockedCardBackground())
    }

    private var filterEmpty: some View {
        Text(filter == .open ? "Nothing left to do in this course." : "Nothing completed yet.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private func save(_ savedAssignment: Assignment) {
        _ = CourseStore.saveAssignment(
            savedAssignment,
            to: courseID,
            courses: &courses,
            keys: &keys,
            karma: &karma
        )
    }

    private func markCompleted(_ assignment: Assignment) {
        var updated = assignment
        updated.completionDate = .now
        save(updated)
    }

    private func markIncomplete(_ assignment: Assignment) {
        var updated = assignment
        updated.completionDate = nil
        save(updated)
    }
}

private struct CourseColorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let courseName: String
    @Binding var selectedIndex: Int

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(courseName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(CourseAccent.palette.indices.contains(selectedIndex)
                                     ? CourseAccent.palette[selectedIndex]
                                     : Color.lockedIndigo)

                CourseColorPicker(selectedIndex: $selectedIndex)

                Text("Tap a color to change it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(LockedBackground())
            .navigationTitle("Course Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .tint(.lockedIndigo)
    }
}

struct CourseProgressHeader: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 18) {
                ZStack {
                    ProgressRing(
                        progress: course.completionPercentage,
                        lineWidth: 8,
                        gradient: LinearGradient(
                            colors: [course.accent, .lockedIndigo],
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
                    MiniStat(value: "\(course.openCount)", label: "Open")
                    MiniStat(value: "\(course.completedCount)", label: "Done")
                    MiniStat(
                        value: "\(course.overdueCount)",
                        label: "Late",
                        emphasize: course.overdueCount > 0
                    )
                }
            }

            if let next = course.nextDueAssignment {
                HStack(spacing: 8) {
                    Image(systemName: next.isOverdue ? "exclamationmark.circle.fill" : "flag.fill")
                        .foregroundStyle(next.isOverdue ? Color.lockedRose : course.accent)
                    Text(next.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(AssignmentDueCopy.countdown(for: next.dueDate))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(next.isOverdue ? Color.lockedRose : .secondary)
                }
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

struct AssignmentRowView: View {
    let assignment: Assignment

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(assignment.name)
                    .font(.body.weight(.semibold))
                    .strikethrough(assignment.isCompleted)
                    .foregroundStyle(assignment.isCompleted ? Color.secondary : Color.primary)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Label(
                        assignment.dueDate.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "calendar"
                    )
                    .foregroundStyle(assignment.isOverdue ? Color.lockedRose : Color.secondary)

                    if assignment.isOverdue {
                        LockedStatusPill(text: "Overdue", color: .lockedRose, filled: true)
                    }
                    if let provider = assignment.sourceProvider {
                        LockedStatusPill(text: provider.title, color: .lockedIndigo)
                    }
                }
                .font(.caption)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                if !assignment.isCompleted {
                    Text(AssignmentDueCopy.countdown(for: assignment.dueDate))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(assignment.isOverdue ? Color.lockedRose : .secondary)
                }
                if let points = assignment.pointsPossible {
                    Text("\(points, specifier: "%.0f") pts")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AssignmentDetailView: View {
    @Binding var courses: [Course]
    let courseID: UUID
    let assignmentID: UUID

    @Environment(\.dismiss) private var dismiss
    @AppStorage("keys", store: .lockedGroup) var keys: Double = 0.0
    @AppStorage("karma", store: .lockedGroup) var karma: Double = 0.0

    @State private var composer: AssignmentComposer?
    @State private var confirmComplete = false
    @State private var confirmPending = false
    @State private var confirmHide = false

    private var resolved: (course: Course, assignment: Assignment)? {
        for course in courses {
            if let assignment = course.assignments.first(where: { $0.id == assignmentID }) {
                return (course, assignment)
            }
        }
        return nil
    }

    private var course: Course? { resolved?.course }
    private var assignment: Assignment? { resolved?.assignment }
    private var resolvedCourseID: UUID { resolved?.course.id ?? courseID }

    var body: some View {
        Group {
            if let course, let assignment {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(course: course, assignment: assignment)
                        facts(assignment: assignment)
                        rewardCard(assignment: assignment)
                        actions(assignment: assignment)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                }
            } else {
                ContentUnavailableView("Assignment unavailable", systemImage: "doc")
            }
        }
        .background(LockedBackground())
        .navigationTitle(assignment?.name ?? "Assignment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if assignment != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        if let assignment {
                            composer = AssignmentComposer(
                                courseID: resolvedCourseID,
                                assignment: assignment,
                                allowsCourseSwitch: courses.count > 1,
                                isNew: false
                            )
                        }
                    }
                }
            }
        }
        .sheet(item: $composer) { draft in
            AssignmentEditorView(
                assignment: draft.assignment,
                courseID: draft.courseID,
                courseOptions: draft.allowsCourseSwitch ? courses : [],
                onSave: { newCourseID, saved in
                    _ = CourseStore.saveAssignment(
                        saved,
                        to: newCourseID,
                        movingFrom: resolvedCourseID,
                        courses: &courses,
                        keys: &keys,
                        karma: &karma
                    )
                }
            )
        }
        .confirmationDialog(
            "Mark \"\(assignment?.name ?? "Assignment")\" as completed?",
            isPresented: $confirmComplete,
            titleVisibility: .visible
        ) {
            Button("Mark as Completed") {
                guard var assignment else { return }
                assignment.completionDate = .now
                _ = CourseStore.saveAssignment(
                    assignment,
                    to: resolvedCourseID,
                    courses: &courses,
                    keys: &keys,
                    karma: &karma
                )
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let assignment {
                let keysGain = Int(assignment.keysReward)
                let preview = assignment.karmaFinishPreview(currentKarma: karma)
                switch preview {
                case .floorsToZero:
                    Text("You’ll earn \(keysGain) Keys. Sets karma to 0.")
                default:
                    Text("You’ll earn \(keysGain) Keys and \(preview.confirmationText).")
                }
            }
        }
        .confirmationDialog(
            "Mark \"\(assignment?.name ?? "Assignment")\" as pending?",
            isPresented: $confirmPending,
            titleVisibility: .visible
        ) {
            Button("Mark as Pending") {
                guard var assignment else { return }
                assignment.completionDate = nil
                _ = CourseStore.saveAssignment(
                    assignment,
                    to: resolvedCourseID,
                    courses: &courses,
                    keys: &keys,
                    karma: &karma
                )
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Hide \"\(assignment?.name ?? "Assignment")\"?",
            isPresented: $confirmHide,
            titleVisibility: .visible
        ) {
            Button("Hide") {
                CourseStore.setAssignmentHidden(
                    assignmentID,
                    in: resolvedCourseID,
                    hidden: true,
                    courses: &courses,
                    keys: &keys,
                    karma: &karma
                )
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It won’t show in Locked or count toward Keys and Karma until you unhide it.")
        }
    }

    private func header(course: Course, assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle().fill(course.accent).frame(width: 8, height: 8)
                Text(course.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(assignment.name)
                .font(.lockedTitle(28))
                .fixedSize(horizontal: false, vertical: true)

            if let provider = assignment.sourceProvider {
                LockedStatusPill(text: provider.title, color: .lockedIndigo)
            }

            TimelineView(.periodic(from: .now, by: 30)) { context in
                VStack(alignment: .leading, spacing: 6) {
                    Text(assignment.isCompleted ? "Completed" : AssignmentDueCopy.countdown(for: assignment.dueDate, now: context.date))
                        .font(.lockedNumber(36))
                        .foregroundStyle(assignment.isCompleted ? Color.lockedTeal : (assignment.isOverdue ? Color.lockedRose : .primary))
                    Text(AssignmentDueCopy.caption(for: assignment.dueDate, now: context.date, completed: assignment.isCompleted))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LockedCardBackground())
    }

    private func facts(assignment: Assignment) -> some View {
        VStack(spacing: 0) {
            factRow(icon: "calendar", title: "Due", value: assignment.dueDate.formatted(date: .abbreviated, time: .shortened))
            Divider().padding(.leading, 52)
            factRow(icon: "tray.and.arrow.down", title: "Assigned", value: assignment.releaseDate.formatted(date: .abbreviated, time: .shortened))
            if let points = assignment.pointsPossible {
                Divider().padding(.leading, 52)
                factRow(icon: "number", title: "Points", value: String(format: "%.0f", points))
            }
            if let completed = assignment.completionDate {
                Divider().padding(.leading, 52)
                factRow(
                    icon: "checkmark.circle.fill",
                    title: assignment.sourceProvider == nil ? "Finished" : "Submitted",
                    value: completed.formatted(date: .abbreviated, time: .shortened)
                )
            }
            if let provider = assignment.sourceProvider {
                Divider().padding(.leading, 52)
                factRow(icon: "link", title: "Source", value: provider.title)
            }
        }
        .background(LockedCardBackground())
    }

    private func factRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.lockedIndigo)
                .frame(width: 28)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func rewardCard(assignment: Assignment) -> some View {
        let karmaPreview = assignment.karmaFinishPreview(
            currentKarma: karma,
            ifCompletedAt: assignment.completionDate ?? .now
        )
        return VStack(alignment: .leading, spacing: 8) {
            LockedSectionLabel(title: assignment.isCompleted ? "Earned" : "If you finish now", icon: "sparkles")
            HStack(spacing: 10) {
                rewardChip(icon: "key.fill", text: "\(Int(assignment.keysReward)) Keys", color: .lockedAmber)
                switch karmaPreview {
                case .gain(let amount):
                    rewardChip(icon: "star.fill", text: "+\(amount) Karma", color: .lockedViolet)
                case .loss(let amount):
                    rewardChip(icon: "star.fill", text: "−\(amount) Karma", color: .lockedRose)
                case .floorsToZero, .unchanged:
                    EmptyView()
                }
            }
            if karmaPreview == .floorsToZero {
                Text("Sets karma to 0")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(assignment.isCompleted
                 ? (assignment.sourceProvider == nil
                    ? "Karma is based on how early you finish relative to the assigned and due dates. Keys are a base of 10 plus the point value."
                    : "Karma used the submitted time from \(assignment.sourceProvider?.title ?? "your source"), not the time you refreshed.")
                 : "Karma is based on how early you finish relative to the assigned and due dates. Keys are a base of 10 plus the point value.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func rewardChip(icon: String, text: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.14))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func actions(assignment: Assignment) -> some View {
        VStack(spacing: 10) {
            if assignment.isCompleted {
                Button {
                    confirmPending = true
                } label: {
                    Label("Mark as pending", systemImage: "arrow.uturn.backward")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            } else {
                Button {
                    confirmComplete = true
                } label: {
                    Label("Mark as completed", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LockedTheme.karmaGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button {
                confirmHide = true
            } label: {
                Label("Hide assignment", systemImage: "eye.slash")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }
}

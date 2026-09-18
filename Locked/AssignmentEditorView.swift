import SwiftUI

struct AssignmentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    let assignment: Assignment
    let onSave: (UUID, Assignment) -> Void

    @State private var name: String
    @State private var dueDate: Date
    @State private var releaseDate: Date
    @State private var isCompleted: Bool
    @State private var completionDate: Date
    @State private var pointsText: String
    @State private var selectedCourseID: UUID

    var courseOptions: [Course]

    enum Field { case name, points }

    private enum DuePreset: String, CaseIterable, Identifiable {
        case tonight, tomorrow, threeDays, nextWeek
        var id: String { rawValue }

        var label: String {
            switch self {
            case .tonight: return "Tonight"
            case .tomorrow: return "Tomorrow"
            case .threeDays: return "In 3 days"
            case .nextWeek: return "Next week"
            }
        }

        func date(from now: Date = .now) -> Date {
            let calendar = Calendar.current
            let days: Int
            switch self {
            case .tonight:
                let end = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: now) ?? now
                return end > now ? end : calendar.date(byAdding: .day, value: 1, to: end) ?? end
            case .tomorrow: days = 1
            case .threeDays: days = 3
            case .nextWeek: days = 7
            }
            let day = calendar.date(byAdding: .day, value: days, to: now) ?? now
            return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: day) ?? day
        }
    }

    init(
        assignment: Assignment,
        courseID: UUID,
        courseOptions: [Course] = [],
        onSave: @escaping (UUID, Assignment) -> Void
    ) {
        self.assignment = assignment
        self.courseOptions = courseOptions
        self.onSave = onSave
        _name = State(initialValue: assignment.name)
        _dueDate = State(initialValue: assignment.dueDate)
        _releaseDate = State(initialValue: assignment.releaseDate)
        _isCompleted = State(initialValue: assignment.completionDate != nil)
        _completionDate = State(initialValue: assignment.completionDate ?? .now)
        _pointsText = State(initialValue: assignment.pointsPossible.map { String($0) } ?? "")
        _selectedCourseID = State(initialValue: courseID)
    }

    private var draft: Assignment {
        Assignment(
            id: assignment.id,
            name: name,
            dueDate: dueDate,
            releaseDate: releaseDate,
            completionDate: isCompleted ? completionDate : nil,
            pointsPossible: Double(pointsText.trimmingCharacters(in: .whitespacesAndNewlines))
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    fieldCard(title: "Assignment") {
                        TextField("Problem set, essay, lab…", text: $name)
                            .font(.title3.weight(.semibold))
                            .focused($focusedField, equals: .name)
                    }

                    if courseOptions.count > 1 {
                        fieldCard(title: "Course") {
                            Picker("Course", selection: $selectedCourseID) {
                                ForEach(courseOptions) { course in
                                    Text(course.name).tag(course.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }

                    fieldCard(title: "Due") {
                        VStack(alignment: .leading, spacing: 14) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(DuePreset.allCases) { preset in
                                        let selected = Calendar.current.isDate(dueDate, inSameDayAs: preset.date())
                                        Button {
                                            dueDate = preset.date()
                                        } label: {
                                            Text(preset.label)
                                                .font(.caption.weight(.semibold))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(selected ? Color.lockedIndigo : Color.primary.opacity(0.08))
                                                .foregroundStyle(selected ? Color.white : Color.primary)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            DatePicker("Due date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                                .foregroundStyle(dueDate < Date.now && !isCompleted ? Color.lockedRose : Color.primary)

                            TimelineView(.periodic(from: .now, by: 60)) { context in
                                Text(AssignmentDueCopy.caption(for: dueDate, now: context.date, completed: isCompleted))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(dueDate < context.date && !isCompleted ? Color.lockedRose : .secondary)
                            }

                            if dueDate < releaseDate {
                                Text("Due is before the assigned date, so completing this won’t change Karma.")
                                    .font(.caption)
                                    .foregroundStyle(Color.lockedRose)
                            }
                        }
                    }

                    fieldCard(title: "Assigned") {
                        DatePicker("Assigned", selection: $releaseDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .accessibilityLabel("Assigned date")
                    }

                    fieldCard(title: "Points / grade weight") {
                        TextField("Optional", text: $pointsText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .points)
                    }

                    fieldCard(title: "Status") {
                        Toggle("Mark as completed", isOn: $isCompleted.animation())
                            .tint(.lockedTeal)
                        if isCompleted {
                            DatePicker("Completed", selection: $completionDate, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                        }
                    }

                    rewardPreview
                }
                .padding(20)
            }
            .background(LockedBackground())
            .navigationTitle(assignment.name.isEmpty ? "New Assignment" : "Edit Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        var saved = draft
                        saved.name = cleaned
                        onSave(selectedCourseID, saved)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
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

    private func fieldCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LockedCardBackground(cornerRadius: 18))
    }

    private var rewardPreview: some View {
        let preview = draft
        let karmaGain = Int(preview.karmaReward().rounded())
        let keysGain = Int(preview.keysReward)
        return VStack(alignment: .leading, spacing: 8) {
            Text("If you finish now")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            HStack {
                Label("\(keysGain) Keys", systemImage: "key.fill")
                    .foregroundStyle(Color.lockedAmber)
                Spacer()
                Label(
                    karmaGain >= 0 ? "+\(karmaGain) Karma" : "\(karmaGain) Karma",
                    systemImage: "star.fill"
                )
                .foregroundStyle(karmaGain >= 0 ? Color.lockedViolet : Color.lockedRose)
            }
            .font(.subheadline.weight(.semibold))
            Text("Finishing early grants more Karma. Keys are 10 plus the point value.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(LockedCardBackground(cornerRadius: 18))
    }
}

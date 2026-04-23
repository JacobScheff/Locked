import SwiftUI

// MARK: - Models

struct Assignment: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var dueDate: Date
    var releaseDate: Date
    var completionDate: Date?
    var pointsPossible: Double?
}

struct Course: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var assignments: [Assignment] = []
}

// MARK: - Courses Page

struct CoursesPage: View {
    @AppStorage("courses", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var courses: [Course] = []

    @State private var editingCourse: Course?

    var body: some View {
        List {
            ForEach(courses) { course in
                NavigationLink {
                    CourseDetailView(courses: $courses, courseID: course.id)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.name)
                            .font(.headline)

                        Text("\(course.assignments.count) assignment\(course.assignments.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button {
                        editingCourse = course
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.blue)

                    Button(role: .destructive) {
                        courses.removeAll { $0.id == course.id }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Courses")
        .toolbar {
            Button {
                editingCourse = Course(name: "")
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(item: $editingCourse) { course in
            CourseEditorView(course: course) { savedCourse in
                if let index = courses.firstIndex(where: { $0.id == savedCourse.id }) {
                    courses[index] = savedCourse
                } else {
                    courses.append(savedCourse)
                }
            }
        }
    }
}

// MARK: - Course Detail

struct CourseDetailView: View {
    @Binding var courses: [Course]
    let courseID: UUID

    @State private var editingAssignment: Assignment?

    private var courseIndex: Int? {
        courses.firstIndex { $0.id == courseID }
    }

    private var course: Course? {
        guard let courseIndex else { return nil }
        return courses[courseIndex]
    }

    var body: some View {
        Group {
            if let course {
                List {
                    if course.assignments.isEmpty {
                        ContentUnavailableView(
                            "No Assignments Yet",
                            systemImage: "doc.text",
                            description: Text("Tap + to add one.")
                        )
                    } else {
                        ForEach(course.assignments) { assignment in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(assignment.name)
                                        .font(.headline)

                                    Spacer()

                                    if assignment.completionDate != nil {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }

                                Text("Due: \(assignment.dueDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text("Release: \(assignment.releaseDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if let completionDate = assignment.completionDate {
                                    Text("Completed: \(completionDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let points = assignment.pointsPossible {
                                    Text("Points: \(points, specifier: "%.1f")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingAssignment = assignment
                            }
                            .swipeActions {
                                Button {
                                    editingAssignment = assignment
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)

                                Button(role: .destructive) {
                                    courses[courseIndex!].assignments.removeAll { $0.id == assignment.id }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Course not found", systemImage: "folder.badge.questionmark")
            }
        }
        .navigationTitle(course?.name ?? "Course")
        .toolbar {
            Button {
                editingAssignment = Assignment(
                    name: "",
                    dueDate: .now,
                    releaseDate: .now,
                    completionDate: nil,
                    pointsPossible: nil
                )
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(item: $editingAssignment) { assignment in
            AssignmentEditorView(assignment: assignment) { savedAssignment in
                guard let courseIndex else { return }

                if let assignmentIndex = courses[courseIndex].assignments.firstIndex(where: { $0.id == savedAssignment.id }) {
                    courses[courseIndex].assignments[assignmentIndex] = savedAssignment
                } else {
                    courses[courseIndex].assignments.append(savedAssignment)
                }
            }
        }
    }
}

// MARK: - Course Editor

struct CourseEditorView: View {
    @Environment(\.dismiss) private var dismiss

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
                Section("Course") {
                    TextField("Course name", text: $name)
                }
            }
            .navigationTitle(course.name.isEmpty ? "New Course" : "Edit Course")
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
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Assignment Editor

struct AssignmentEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let assignment: Assignment
    let onSave: (Assignment) -> Void

    @State private var name: String
    @State private var dueDate: Date
    @State private var releaseDate: Date
    @State private var isCompleted: Bool
    @State private var completionDate: Date
    @State private var pointsText: String

    init(assignment: Assignment, onSave: @escaping (Assignment) -> Void) {
        self.assignment = assignment
        self.onSave = onSave

        _name = State(initialValue: assignment.name)
        _dueDate = State(initialValue: assignment.dueDate)
        _releaseDate = State(initialValue: assignment.releaseDate)
        _isCompleted = State(initialValue: assignment.completionDate != nil)
        _completionDate = State(initialValue: assignment.completionDate ?? .now)
        _pointsText = State(initialValue: assignment.pointsPossible.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Assignment") {
                    TextField("Name", text: $name)
                    DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    DatePicker("Release date", selection: $releaseDate, displayedComponents: .date)
                }

                Section("Completion") {
                    Toggle("Finished", isOn: $isCompleted)

                    if isCompleted {
                        DatePicker("Completion date", selection: $completionDate, displayedComponents: .date)
                    }
                }

                Section("Optional") {
                    TextField("Points / grade weight", text: $pointsText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(assignment.name.isEmpty ? "New Assignment" : "Edit Assignment")
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
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

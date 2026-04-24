import SwiftUI

// MARK: - Models

struct Assignment: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var dueDate: Date
    var releaseDate: Date
    var completionDate: Date?
    var pointsPossible: Double?
    
    // UX Helpers
    var isCompleted: Bool { completionDate != nil }
    var isOverdue: Bool { !isCompleted && dueDate < Date.now }
    
    var statusColor: Color {
        if isCompleted { return .green }
        if isOverdue { return .red }
        return .blue
    }
}

struct Course: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var assignments: [Assignment] = []
    
    // UX Helpers
    var completionPercentage: Double {
        guard !assignments.isEmpty else { return 0 }
        let completed = assignments.filter { $0.isCompleted }.count
        return Double(completed) / Double(assignments.count)
    }
}

// MARK: - Courses Page

struct CoursesPage: View {
    @AppStorage("courses", store: UserDefaults(suiteName: "group.com.Jacob-Scheff.Locked"))
    var courses: [Course] = []

    @State private var editingCourse: Course?
    @State private var courseToDelete: Course?

    var body: some View {
        NavigationStack {
            List {
                ForEach(courses) { course in
                    NavigationLink {
                        CourseDetailView(courses: $courses, courseID: course.id)
                    } label: {
                        CourseRowView(course: course)
                    }
                    .swipeActions {
                        Button {
                            courseToDelete = course
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)  // manually set red since we dropped the destructive role
                        
                        Button {
                            editingCourse = course
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                }
            }
            .navigationTitle("My Courses")
            .overlay {
                if courses.isEmpty {
                    ContentUnavailableView(
                        "No Courses",
                        systemImage: "books.vertical",
                        description: Text("Tap the + button to create your first course.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingCourse = Course(name: "")
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
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
    }
}

// MARK: - UI Components

struct CourseRowView: View {
    let course: Course
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: course.completionPercentage)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.headline)
                
                Text("\(course.assignments.count) Assignment\(course.assignments.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Course Detail

struct CourseDetailView: View {
    @Binding var courses: [Course]
    let courseID: UUID

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
                    if course.assignments.isEmpty {
                        ContentUnavailableView(
                            "No Assignments",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("Add assignments to track your progress.")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        if !pendingAssignments.isEmpty {
                            Section("To Do") {
                                ForEach(pendingAssignments) { assignment in
                                    AssignmentRowView(assignment: assignment)
                                        .contentShape(Rectangle())
                                        .onTapGesture { editingAssignment = assignment }
                                        .swipeActions(edge: .leading) {
                                            Button { assignmentToComplete = assignment } label: {
                                                Label("Complete", systemImage: "checkmark")
                                            }
                                            .tint(.green)
                                        }
                                        .swipeActions(edge: .trailing) { deleteAndEditActions(for: assignment) }
                                }
                            }
                        }
                        
                        if !completedAssignments.isEmpty {
                            Section("Completed") {
                                ForEach(completedAssignments) { assignment in
                                    AssignmentRowView(assignment: assignment)
                                        .contentShape(Rectangle())
                                        .onTapGesture { editingAssignment = assignment }
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
                .listStyle(.insetGrouped)
                .animation(.default, value: course.assignments)
            }
        }
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
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
        }
        .sheet(item: $editingAssignment) { assignment in
            AssignmentEditorView(assignment: assignment) { savedAssignment in
                saveAssignment(savedAssignment)
            }
        }
        // Delete confirmation
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
        // Mark complete confirmation
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
        }
        // Mark incomplete confirmation
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
    
    // MARK: Actions
    
    // In CourseDetailView - deleteAndEditActions
    @ViewBuilder
    private func deleteAndEditActions(for assignment: Assignment) -> some View {
        Button {
            assignmentToDelete = assignment
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .tint(.red)  // manually set red since we dropped the destructive role
        
        Button {
            editingAssignment = assignment
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        .tint(.orange)
    }
    
    private func saveAssignment(_ savedAssignment: Assignment) {
        guard let courseIndex else { return }
        withAnimation {
            if let assignmentIndex = courses[courseIndex].assignments.firstIndex(where: { $0.id == savedAssignment.id }) {
                courses[courseIndex].assignments[assignmentIndex] = savedAssignment
            } else {
                courses[courseIndex].assignments.append(savedAssignment)
            }
        }
    }
        
    private func markCompleted(_ assignment: Assignment) {
            var updated = assignment
            updated.completionDate = .now
            saveAssignment(updated)

            // 1. Update Karma based on how early/late this was completed
            updateKarmaForAssignment(
                releaseDate: assignment.releaseDate,
                dueDate: assignment.dueDate,
                completionDate: .now
            )
            
            // 2. Grant Keys (e.g., 5 base keys + whatever points the assignment was worth)
            let baseKeys = 5.0
            let pointBonus = assignment.pointsPossible ?? 0.0
            LogicStore.shared.keys += (baseKeys + pointBonus)
        }
    
    private func markIncomplete(_ assignment: Assignment) {
        var updated = assignment
        updated.completionDate = nil
        saveAssignment(updated)
    }
}

// MARK: - Assignment Row View

struct AssignmentRowView: View {
    let assignment: Assignment
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: assignment.isCompleted ? "checkmark.circle.fill" : (assignment.isOverdue ? "exclamationmark.circle.fill" : "circle"))
                .font(.title2)
                .foregroundStyle(assignment.statusColor)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(assignment.name)
                    .font(.headline)
                    .strikethrough(assignment.isCompleted)
                    .foregroundStyle(assignment.isCompleted ? .secondary : .primary)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: "calendar")
                        Text("Due: \(assignment.dueDate.formatted(date: .abbreviated, time: .shortened))")
                            .foregroundStyle(assignment.isOverdue ? .red : .secondary)
                    }
                    
                    if let completionDate = assignment.completionDate {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Done: \(completionDate.formatted(date: .abbreviated, time: .omitted))")
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let points = assignment.pointsPossible {
                VStack {
                    Text("\(points, specifier: "%.1f")")
                        .font(.subheadline.bold())
                    Text("pts")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 4)
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
                }
            }
            .navigationTitle(course.name.isEmpty ? "New Course" : "Edit Course")
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
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
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
                    DatePicker("Release Date", selection: $releaseDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                        .foregroundStyle(dueDate < Date.now && !isCompleted ? .red : .primary)
                }

                Section("Status") {
                    Toggle("Mark as Completed", isOn: $isCompleted.animation())
                        .tint(.green)

                    if isCompleted {
                        DatePicker("Completion Date", selection: $completionDate, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                    }
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
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                // Keyboard toolbar to dismiss decimal pad
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
    }
}

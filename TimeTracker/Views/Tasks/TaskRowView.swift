import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: TrackedTask
    var isKeyboardSelected: Bool = false
    var shouldEdit: Bool = false
    var shouldDelete: Bool = false
    var onEditHandled: (() -> Void)?
    var onDeleteHandled: (() -> Void)?
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var timeTrackingManager: TimeTrackingManager
    @ObservedObject private var undoManager = AppUndoManager.shared
    
    @Query(sort: \Project.name) private var projects: [Project]
    
    @State private var showingDeleteConfirmation = false
    @State private var showingEditMode = false
    
    // Edit state
    @State private var editName: String = ""
    @State private var editHours: Int = 0
    @State private var editMinutes: Int = 0
    @State private var editProject: Project?
    @State private var editNotes: String = ""
    @State private var showingNotes = false
    
    private var isActive: Bool {
        timeTrackingManager.isTaskActive(task)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if showingDeleteConfirmation {
                // Inline delete confirmation
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete \"\(task.name)\"?")
                            .font(.callout)
                            .fontWeight(.medium)
                        Text("This will delete all time entries")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Cancel") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showingDeleteConfirmation = false
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    
                    Button("Delete") {
                        deleteTask()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            } else if showingEditMode {
                // Inline edit mode
                VStack(alignment: .leading, spacing: 12) {
                    // Task name
                    TextField("Task name", text: $editName)
                        .textFieldStyle(.roundedBorder)
                    
                    // Time estimate
                    HStack {
                        Text("Estimate:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Picker("Hours", selection: $editHours) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text("\(hour)h").tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 60)
                        
                        Picker("Minutes", selection: $editMinutes) {
                            ForEach([0, 5, 10, 15, 20, 25, 30, 45], id: \.self) { minute in
                                Text("\(minute)m").tag(minute)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 60)
                        
                        Spacer()
                    }
                    
                    // Project selection
                    HStack {
                        Text("Project:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Picker("Project", selection: $editProject) {
                            Text("No Project").tag(nil as Project?)
                            
                            ForEach(projects) { project in
                                HStack {
                                    Circle()
                                        .fill(project.color)
                                        .frame(width: 8, height: 8)
                                    Text(project.name)
                                }
                                .tag(project as Project?)
                            }
                        }
                        .labelsHidden()
                        
                        Spacer()
                    }
                    
                    // Notes
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("Add notes...", text: $editNotes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...5)
                    }
                    
                    // Action buttons
                    HStack {
                        Spacer()
                        
                        Button("Cancel") {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showingEditMode = false
                            }
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        
                        Button("Save") {
                            saveEdit()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
            } else {
                // Normal task row
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // Project color indicator
                        if let project = task.project {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(project.color)
                                .frame(width: 4)
                        }
                        
                        // Task info
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(task.name)
                                    .font(.body)
                                    .lineLimit(1)
                                
                                if task.hasNotes {
                                    Image(systemName: "note.text")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            HStack(spacing: 8) {
                                // Estimate
                                Label(task.formattedEstimate, systemImage: "target")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                // Tracked time
                                if task.totalTrackedSeconds > 0 {
                                    Label(task.formattedTracked, systemImage: "clock")
                                        .font(.caption)
                                        .foregroundStyle(task.remainingSeconds < 0 ? .red : .secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Play/Stop button
                        Button(action: toggleTracking) {
                            Image(systemName: isActive ? "stop.circle.fill" : "play.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(isActive ? .red : .green)
                        }
                        .buttonStyle(.borderless)
                        
                        // More options menu
                        Menu {
                            Button("Edit") {
                                startEditing()
                            }
                            
                            if task.hasNotes {
                                Button(showingNotes ? "Hide Notes" : "Show Notes") {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        showingNotes.toggle()
                                    }
                                }
                            }
                            
                            Button("Mark Complete") {
                                task.isCompleted = true
                                if isActive {
                                    timeTrackingManager.stopTracking(context: modelContext)
                                }
                            }
                            
                            Divider()
                            
                            Button("Delete", role: .destructive) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    showingDeleteConfirmation = true
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .foregroundStyle(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .frame(width: 24)
                    }
                    .padding(12)
                    
                    // Notes display
                    if showingNotes, let notes = task.notes, !notes.isEmpty {
                        Divider()
                            .padding(.horizontal, 12)
                        
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                }
                .background(
                    isKeyboardSelected ? Color.accentColor.opacity(0.2) :
                    isActive ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor)
                )
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isKeyboardSelected ? Color.accentColor : .clear, lineWidth: 2)
                )
                .animation(.easeInOut(duration: 0.2), value: isActive)
                .animation(.easeInOut(duration: 0.15), value: isKeyboardSelected)
            }
        }
        .onChange(of: shouldEdit) { _, newValue in
            if newValue {
                startEditing()
                onEditHandled?()
            }
        }
        .onChange(of: shouldDelete) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showingDeleteConfirmation = true
                }
                onDeleteHandled?()
            }
        }
    }
    
    private func startEditing() {
        // Initialize edit state from current task values
        editName = task.name
        editHours = task.estimatedSeconds / 3600
        editMinutes = (task.estimatedSeconds % 3600) / 60
        editProject = task.project
        editNotes = task.notes ?? ""
        
        withAnimation(.easeInOut(duration: 0.15)) {
            showingEditMode = true
        }
    }
    
    private func saveEdit() {
        task.name = editName.trimmingCharacters(in: .whitespaces)
        task.estimatedSeconds = editHours * 3600 + editMinutes * 60
        task.project = editProject
        task.notes = editNotes.isEmpty ? nil : editNotes
        
        withAnimation(.easeInOut(duration: 0.15)) {
            showingEditMode = false
        }
    }
    
    private func toggleTracking() {
        if isActive {
            timeTrackingManager.stopTracking(context: modelContext)
        } else {
            timeTrackingManager.startTracking(task: task, context: modelContext)
        }
    }
    
    private func deleteTask() {
        if isActive {
            timeTrackingManager.stopTracking(context: modelContext)
        }
        
        // Store task data for undo
        let taskName = task.name
        let taskEstimatedSeconds = task.estimatedSeconds
        let taskProject = task.project
        let taskOrderIndex = task.orderIndex
        let taskNotes = task.notes
        let taskTimeEntries = task.timeEntries ?? []
        
        // Store time entry data
        let entryData = taskTimeEntries.map { entry in
            (startTime: entry.startTime, endTime: entry.endTime)
        }
        
        // Delete the task
        modelContext.delete(task)
        try? modelContext.save()
        
        // Show undo toast
        undoManager.showUndo(message: "Deleted \"\(taskName)\"") { [weak modelContext] in
            guard let modelContext = modelContext else { return }
            
            // Recreate the task
            let restoredTask = TrackedTask(
                name: taskName,
                estimatedSeconds: taskEstimatedSeconds,
                project: taskProject,
                orderIndex: taskOrderIndex,
                notes: taskNotes
            )
            modelContext.insert(restoredTask)
            
            // Recreate time entries
            for entryInfo in entryData {
                let entry = TimeEntry(task: restoredTask)
                entry.startTime = entryInfo.startTime
                entry.endTime = entryInfo.endTime
                modelContext.insert(entry)
            }
            
            try? modelContext.save()
        }
        
        showingDeleteConfirmation = false
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, TrackedTask.self, TimeEntry.self, configurations: config)
    
    let project = Project(name: "Work", colorHex: "#FF5733")
    container.mainContext.insert(project)
    
    let task = TrackedTask(name: "Design new feature", estimatedSeconds: 3600, project: project)
    container.mainContext.insert(task)
    
    return TaskRowView(task: task)
        .modelContainer(container)
        .environmentObject(TimeTrackingManager())
        .padding()
        .frame(width: 340)
}

import SwiftUI
import SwiftData

struct DayDetailView: View {
    let date: Date
    let entries: [TimeEntry]
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TrackedTask> { !$0.isCompleted }, sort: \TrackedTask.name) private var tasks: [TrackedTask]
    
    @State private var showingAddEntry = false
    @State private var newEntryTask: TrackedTask?
    @State private var newEntryStartTime: Date = Date()
    @State private var newEntryEndTime: Date = Date()
    
    private var totalSeconds: Int {
        entries.reduce(0) { $0 + $1.durationSeconds }
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(dateString)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if totalSeconds > 0 {
                    Text("Total: \(TimeFormatter.formatHoursMinutes(seconds: totalSeconds))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button(action: { showAddEntry() }) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Add manual time entry")
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Add entry form
            if showingAddEntry {
                AddTimeEntryForm(
                    tasks: tasks,
                    selectedTask: $newEntryTask,
                    startTime: $newEntryStartTime,
                    endTime: $newEntryEndTime,
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showingAddEntry = false
                        }
                    },
                    onSave: {
                        saveNewEntry()
                    }
                )
                .padding(.horizontal)
            }
            
            if entries.isEmpty && !showingAddEntry {
                VStack {
                    Text("No time tracked")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Entries list
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(sortedEntries) { entry in
                            TimeEntryRowView(entry: entry)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private var sortedEntries: [TimeEntry] {
        entries.sorted { $0.startTime > $1.startTime }
    }
    
    private func showAddEntry() {
        // Set default times for the selected date
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 9
        components.minute = 0
        newEntryStartTime = calendar.date(from: components) ?? date
        
        components.hour = 10
        newEntryEndTime = calendar.date(from: components) ?? date.addingTimeInterval(3600)
        
        newEntryTask = tasks.first
        
        withAnimation(.easeInOut(duration: 0.15)) {
            showingAddEntry = true
        }
    }
    
    private func saveNewEntry() {
        guard let task = newEntryTask, newEntryEndTime > newEntryStartTime else { return }
        
        let entry = TimeEntry(task: task)
        entry.startTime = newEntryStartTime
        entry.endTime = newEntryEndTime
        modelContext.insert(entry)
        
        try? modelContext.save()
        
        withAnimation(.easeInOut(duration: 0.15)) {
            showingAddEntry = false
        }
    }
}

struct AddTimeEntryForm: View {
    let tasks: [TrackedTask]
    @Binding var selectedTask: TrackedTask?
    @Binding var startTime: Date
    @Binding var endTime: Date
    let onCancel: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Task picker
            HStack {
                Text("Task:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
                
                Picker("Task", selection: $selectedTask) {
                    Text("Select task").tag(nil as TrackedTask?)
                    ForEach(tasks) { task in
                        HStack {
                            if let project = task.project {
                                Circle()
                                    .fill(project.color)
                                    .frame(width: 8, height: 8)
                            }
                            Text(task.name)
                        }
                        .tag(task as TrackedTask?)
                    }
                }
                .labelsHidden()
            }
            
            HStack {
                Text("Start:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
                
                DatePicker("", selection: $startTime, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.field)
            }
            
            HStack {
                Text("End:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
                
                DatePicker("", selection: $endTime, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.field)
            }
            
            HStack {
                Spacer()
                
                Button("Cancel", action: onCancel)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .controlSize(.small)
                
                Button("Add Entry", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(selectedTask == nil || endTime <= startTime)
            }
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(8)
    }
}

struct TimeEntryRowView: View {
    @Bindable var entry: TimeEntry
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var undoManager = AppUndoManager.shared
    
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var editStartTime: Date = Date()
    @State private var editEndTime: Date = Date()
    
    var body: some View {
        VStack(spacing: 0) {
            if showingDeleteConfirmation {
                // Delete confirmation
                HStack(spacing: 12) {
                    Text("Delete this entry?")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showingDeleteConfirmation = false
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .controlSize(.small)
                    
                    Button("Delete") {
                        deleteEntry()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            } else if isEditing {
                // Edit mode
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Start:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                        
                        DatePicker("", selection: $editStartTime, displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.field)
                    }
                    
                    HStack {
                        Text("End:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                        
                        DatePicker("", selection: $editEndTime, displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.field)
                    }
                    
                    HStack {
                        Spacer()
                        
                        Button("Cancel") {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isEditing = false
                            }
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .controlSize(.small)
                        
                        Button("Save") {
                            saveEdit()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(editEndTime <= editStartTime)
                    }
                }
                .padding(8)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)
            } else {
                // Normal view
                HStack(spacing: 10) {
                    // Project color
                    if let project = entry.task?.project {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(project.color)
                            .frame(width: 3)
                    } else {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 3)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.task?.name ?? "Unknown Task")
                            .font(.caption)
                            .lineLimit(1)
                        
                        HStack(spacing: 8) {
                            Text(entry.formattedTimeRange)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            
                            if let projectName = entry.task?.project?.name {
                                Text(projectName)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Text(entry.formattedDuration)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    
                    // Actions menu
                    Menu {
                        Button("Edit") {
                            startEditing()
                        }
                        
                        Divider()
                        
                        Button("Delete", role: .destructive) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showingDeleteConfirmation = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 20)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            }
        }
    }
    
    private func startEditing() {
        editStartTime = entry.startTime
        editEndTime = entry.endTime ?? Date()
        withAnimation(.easeInOut(duration: 0.15)) {
            isEditing = true
        }
    }
    
    private func saveEdit() {
        entry.startTime = editStartTime
        entry.endTime = editEndTime
        try? modelContext.save()
        withAnimation(.easeInOut(duration: 0.15)) {
            isEditing = false
        }
    }
    
    private func deleteEntry() {
        // Store entry data for undo
        let entryTask = entry.task
        let entryStartTime = entry.startTime
        let entryEndTime = entry.endTime
        let taskName = entryTask?.name ?? "Unknown"
        
        // Delete the entry
        modelContext.delete(entry)
        try? modelContext.save()
        
        // Show undo toast
        undoManager.showUndo(message: "Deleted time entry for \"\(taskName)\"") { [weak modelContext] in
            guard let modelContext = modelContext else { return }
            
            // Recreate the entry
            let restoredEntry = TimeEntry(task: entryTask)
            restoredEntry.startTime = entryStartTime
            restoredEntry.endTime = entryEndTime
            modelContext.insert(restoredEntry)
            
            try? modelContext.save()
        }
        
        showingDeleteConfirmation = false
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, TrackedTask.self, TimeEntry.self, configurations: config)
    
    // Add sample data
    let project = Project(name: "Work", colorHex: "#007AFF")
    container.mainContext.insert(project)
    
    let task = TrackedTask(name: "Code review", estimatedSeconds: 3600, project: project)
    container.mainContext.insert(task)
    
    let entry = TimeEntry(task: task)
    entry.endTime = Date().addingTimeInterval(1800)
    container.mainContext.insert(entry)
    
    return DayDetailView(date: Date(), entries: [entry])
        .modelContainer(container)
        .frame(width: 340, height: 200)
}

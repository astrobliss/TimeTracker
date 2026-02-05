import SwiftUI
import SwiftData
import AppKit

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var timeTrackingManager: TimeTrackingManager
    
    @Query(sort: \Project.createdAt) private var projects: [Project]
    @Query(filter: #Predicate<TrackedTask> { !$0.isCompleted }, sort: \TrackedTask.orderIndex) private var activeTasks: [TrackedTask]
    
    let onManageProjects: () -> Void
    
    @State private var newTaskInput = ""
    @State private var newTaskTime = "30:00"
    @State private var draggingTask: TrackedTask?
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Active timer display
            if let task = timeTrackingManager.activeTask,
               let remaining = timeTrackingManager.remainingSeconds {
                ActiveTimerBanner(task: task, remainingSeconds: remaining)
            }
            
            // Task list
            ScrollView {
                LazyVStack(spacing: 8) {
                    if activeTasks.isEmpty {
                        EmptyTasksView()
                    } else {
                        // Group tasks by project
                        ForEach(groupedTasks.keys.sorted(), id: \.self) { projectName in
                            if let tasks = groupedTasks[projectName] {
                                TaskGroupView(
                                    projectName: projectName,
                                    tasks: tasks,
                                    draggingTask: $draggingTask,
                                    onReorder: { fromTask, toTask in
                                        reorderTask(fromTask, to: toTask)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Quick add task bar at bottom
            QuickAddTaskBar(
                taskInput: $newTaskInput,
                timeInput: $newTaskTime,
                isInputFocused: $isInputFocused,
                projects: projects,
                onSubmit: addTask
            )
            
            // Bottom toolbar
            HStack {
                Spacer()
                
                Button(action: onManageProjects) {
                    Image(systemName: "folder.badge.gearshape")
                }
                .buttonStyle(.borderless)
                .help("Manage Projects")
                
                SettingsMenuView()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
    
    private var groupedTasks: [String: [TrackedTask]] {
        var groups: [String: [TrackedTask]] = [:]
        for task in activeTasks {
            let projectName = task.project?.name ?? "No Project"
            if groups[projectName] == nil {
                groups[projectName] = []
            }
            groups[projectName]?.append(task)
        }
        // Tasks are already sorted by orderIndex from the query
        return groups
    }
    
    private func reorderTask(_ fromTask: TrackedTask, to toTask: TrackedTask) {
        guard fromTask.id != toTask.id else { return }
        
        // Get all tasks in the same project group
        let projectName = fromTask.project?.name ?? "No Project"
        guard var tasksInGroup = groupedTasks[projectName] else { return }
        
        // Find indices
        guard let fromIndex = tasksInGroup.firstIndex(where: { $0.id == fromTask.id }),
              let toIndex = tasksInGroup.firstIndex(where: { $0.id == toTask.id }) else { return }
        
        // Reorder the array
        let task = tasksInGroup.remove(at: fromIndex)
        tasksInGroup.insert(task, at: toIndex)
        
        // Update orderIndex for all tasks in the group
        for (index, task) in tasksInGroup.enumerated() {
            task.orderIndex = index
        }
    }
    
    private func addTask() {
        let parsed = TaskInputParser.parse(input: newTaskInput, time: newTaskTime, existingProjects: projects)
        
        guard !parsed.taskName.isEmpty else { return }
        
        // Find or create project
        var project: Project? = nil
        if let projectName = parsed.projectName {
            if let existing = projects.first(where: { $0.name.lowercased() == projectName.lowercased() }) {
                project = existing
            } else {
                // Create new project with random color
                let colors = ["#FF5733", "#FF8C00", "#FFD700", "#32CD32", "#007AFF", "#5856D6", "#AF52DE", "#FF2D55"]
                let newProject = Project(name: projectName, colorHex: colors.randomElement() ?? "#007AFF")
                modelContext.insert(newProject)
                project = newProject
            }
        }
        
        // Calculate the next orderIndex (put new tasks at the top)
        let maxOrderIndex = activeTasks.map(\.orderIndex).max() ?? -1
        
        let task = TrackedTask(
            name: parsed.taskName,
            estimatedSeconds: parsed.estimatedSeconds,
            project: project,
            orderIndex: maxOrderIndex + 1
        )
        modelContext.insert(task)
        
        // Reset input
        newTaskInput = ""
        newTaskTime = "30:00"
    }
}

// MARK: - Quick Add Task Bar

struct QuickAddTaskBar: View {
    @Binding var taskInput: String
    @Binding var timeInput: String
    var isInputFocused: FocusState<Bool>.Binding
    let projects: [Project]
    let onSubmit: () -> Void
    
    @State private var showingSuggestions = false
    
    private var parsedPreview: TaskInputParser.ParsedTask {
        TaskInputParser.parse(input: taskInput, time: timeInput, existingProjects: projects)
    }
    
    private var matchedProject: Project? {
        guard let projectName = parsedPreview.projectName else { return nil }
        return projects.first { $0.name.lowercased() == projectName.lowercased() }
    }
    
    // Get current @mention being typed
    private var currentMention: String? {
        guard let atIndex = taskInput.lastIndex(of: "@") else { return nil }
        let afterAt = taskInput[taskInput.index(after: atIndex)...]
        // Check if there's a space after - if so, mention is complete
        if afterAt.contains(" ") { return nil }
        return String(afterAt)
    }
    
    // Filter projects based on current mention
    private var suggestedProjects: [Project] {
        guard let mention = currentMention else { return [] }
        if mention.isEmpty { return projects }
        return projects.filter { $0.name.lowercased().hasPrefix(mention.lowercased()) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Project suggestions (above input)
            if showingSuggestions && !suggestedProjects.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestedProjects.prefix(5)) { project in
                        Button(action: { applyProjectSuggestion(project) }) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(project.color)
                                    .frame(width: 8, height: 8)
                                Text(project.name)
                                    .font(.callout)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.1), radius: 4, y: -2)
                .padding(.bottom, 4)
            }
            
            // Preview line (above input)
            if !taskInput.isEmpty && !showingSuggestions {
                HStack(spacing: 4) {
                    if let project = matchedProject {
                        Circle()
                            .fill(project.color)
                            .frame(width: 6, height: 6)
                        Text(project.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if let projectName = parsedPreview.projectName {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 6, height: 6)
                        Text("+ \(projectName)")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    
                    if parsedPreview.projectName != nil {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                    }
                    
                    Text(TimeFormatter.format(seconds: parsedPreview.estimatedSeconds))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            }
            
            // Main input row
            HStack(spacing: 8) {
                // Task name input
                TextField("Task name @project", text: $taskInput)
                    .textFieldStyle(.plain)
                    .focused(isInputFocused)
                    .onChange(of: taskInput) { _, newValue in
                        showingSuggestions = currentMention != nil && !suggestedProjects.isEmpty
                    }
                    .onSubmit {
                        if showingSuggestions, let first = suggestedProjects.first {
                            applyProjectSuggestion(first)
                        } else {
                            onSubmit()
                        }
                    }
                
                // Time input
                TextField("0:00", text: $timeInput)
                    .textFieldStyle(.plain)
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
                    .foregroundColor(isValidTime ? .primary : .red)
                    .onSubmit(onSubmit)
                
                // Add button
                Button(action: onSubmit) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.borderless)
                .disabled(taskInput.trimmingCharacters(in: .whitespaces).isEmpty || !isValidTime)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .padding(12)
    }
    
    private var isValidTime: Bool {
        TaskInputParser.parseTime(timeInput) != nil
    }
    
    private func applyProjectSuggestion(_ project: Project) {
        // Replace the @mention with the full project name
        if let atIndex = taskInput.lastIndex(of: "@") {
            taskInput = String(taskInput[..<atIndex]) + "@\(project.name) "
        }
        showingSuggestions = false
    }
}

// MARK: - Task Input Parser

enum TaskInputParser {
    struct ParsedTask {
        let taskName: String
        let projectName: String?
        let estimatedSeconds: Int
    }
    
    static func parse(input: String, time: String, existingProjects: [Project]) -> ParsedTask {
        var taskName = input.trimmingCharacters(in: .whitespaces)
        var projectName: String? = nil
        
        // Extract @project (handles multi-word projects with quotes or single words)
        if let match = taskName.range(of: "@\\S+", options: .regularExpression) {
            let fullMatch = String(taskName[match])
            projectName = String(fullMatch.dropFirst()) // Remove @
            taskName = taskName.replacingCharacters(in: match, with: "").trimmingCharacters(in: .whitespaces)
        }
        
        // Parse time
        let seconds = parseTime(time) ?? 1800 // Default 30 min
        
        return ParsedTask(
            taskName: taskName,
            projectName: projectName,
            estimatedSeconds: seconds
        )
    }
    
    static func parseTime(_ input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        
        // Handle empty input
        if trimmed.isEmpty { return nil }
        
        // Split by colon
        let components = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        
        switch components.count {
        case 1:
            // Just a number - treat as minutes
            guard let minutes = Int(trimmed), minutes >= 0 else { return nil }
            return minutes * 60
            
        case 2:
            // MM:SS format
            guard let part1 = Int(components[0]),
                  let part2 = Int(components[1]),
                  part1 >= 0, part2 >= 0, part2 < 60 else { return nil }
            return part1 * 60 + part2
            
        case 3:
            // H:MM:SS format
            guard let hours = Int(components[0]),
                  let minutes = Int(components[1]),
                  let seconds = Int(components[2]),
                  hours >= 0, minutes >= 0, minutes < 60, seconds >= 0, seconds < 60 else { return nil }
            return hours * 3600 + minutes * 60 + seconds
            
        default:
            return nil
        }
    }
}

// MARK: - Supporting Views

struct ActiveTimerBanner: View {
    let task: TrackedTask
    let remainingSeconds: Int
    @EnvironmentObject private var timeTrackingManager: TimeTrackingManager
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.headline)
                    .lineLimit(1)
                
                if let project = task.project {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(project.color)
                            .frame(width: 6, height: 6)
                        Text(project.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Text(TimeFormatter.format(seconds: remainingSeconds, showSign: true))
                .font(.system(.title2, design: .monospaced))
                .foregroundStyle(remainingSeconds < 0 ? .red : .primary)
            
            Button(action: {
                timeTrackingManager.stopTracking(context: modelContext)
            }) {
                Image(systemName: "stop.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Stop tracking (⌘.)")
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
    }
}

struct TaskGroupView: View {
    let projectName: String
    let tasks: [TrackedTask]
    @Binding var draggingTask: TrackedTask?
    let onReorder: (TrackedTask, TrackedTask) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(projectName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            ForEach(tasks) { task in
                TaskRowView(task: task)
                    .opacity(draggingTask?.id == task.id ? 0.5 : 1.0)
                    .draggable(task.id.uuidString) {
                        // Drag preview
                        TaskDragPreview(task: task)
                            .onAppear {
                                draggingTask = task
                            }
                    }
                    .dropDestination(for: String.self) { items, location in
                        guard let draggedTaskId = items.first,
                              let draggedTask = draggingTask,
                              draggedTaskId == draggedTask.id.uuidString else {
                            return false
                        }
                        
                        // Only allow reordering within the same project
                        let draggedProjectName = draggedTask.project?.name ?? "No Project"
                        if draggedProjectName == projectName {
                            onReorder(draggedTask, task)
                        }
                        return true
                    } isTargeted: { isTargeted in
                        // Visual feedback when dragging over
                    }
            }
        }
        .onChange(of: draggingTask) { oldValue, newValue in
            if newValue == nil {
                // Drag ended
            }
        }
    }
}

struct TaskDragPreview: View {
    let task: TrackedTask
    
    var body: some View {
        HStack(spacing: 8) {
            if let project = task.project {
                RoundedRectangle(cornerRadius: 2)
                    .fill(project.color)
                    .frame(width: 4, height: 24)
            }
            Text(task.name)
                .font(.body)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }
}

struct EmptyTasksView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No active tasks")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Add a task below to start")
                .font(.caption)
                .foregroundStyle(Color.gray.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Settings Menu

struct SettingsMenuView: View {
    @StateObject private var launchAtLogin = LaunchAtLoginManager.shared
    
    var body: some View {
        Menu {
            Toggle("Launch at Login", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { _ in launchAtLogin.toggle() }
            ))
            
            Divider()
            
            Button("Quit Time Tracker") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            Image(systemName: "gearshape")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

#Preview {
    TaskListView(onManageProjects: {})
        .modelContainer(for: [Project.self, TrackedTask.self, TimeEntry.self], inMemory: true)
        .environmentObject(TimeTrackingManager())
        .frame(width: 360, height: 500)
}

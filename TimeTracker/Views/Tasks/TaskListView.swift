import SwiftUI
import SwiftData

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
    
    // Search and filter state
    @State private var searchText = ""
    @State private var selectedFilter: TaskFilter = .all
    @State private var selectedProjectFilter: Project?
    @State private var showingFilters = false
    @State private var showSearchBar = false
    @FocusState private var isSearchFocused: Bool
    
    // Keyboard navigation state
    @State private var selectedTaskId: UUID?
    @FocusState private var isTaskListFocused: Bool
    
    enum TaskFilter: String, CaseIterable {
        case all = "All"
        case todayTracked = "Tracked Today"
        case hasTimeLeft = "Time Remaining"
        case overTime = "Over Time"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Active timer display
            if let task = timeTrackingManager.activeTask,
               let remaining = timeTrackingManager.remainingSeconds {
                ActiveTimerBanner(task: task, remainingSeconds: remaining)
            }
            
            // Search and filter bar (revealed by ⌘F or when active)
            if isSearchBarVisible {
                SearchFilterBar(
                    searchText: $searchText,
                    selectedFilter: $selectedFilter,
                    selectedProject: $selectedProjectFilter,
                    projects: projects,
                    showingFilters: $showingFilters,
                    isSearchFocused: $isSearchFocused
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Task list
            ScrollView {
                LazyVStack(spacing: 8) {
                    if filteredTasks.isEmpty {
                        if activeTasks.isEmpty {
                            EmptyTasksView()
                        } else {
                            NoResultsView(searchText: searchText, filter: selectedFilter)
                        }
                    } else {
                        // Group tasks by project
                        ForEach(filteredGroupedTasks.keys.sorted(), id: \.self) { projectName in
                            if let tasks = filteredGroupedTasks[projectName] {
                                TaskGroupView(
                                    projectName: projectName,
                                    tasks: tasks,
                                    draggingTask: $draggingTask,
                                    selectedTaskId: $selectedTaskId,
                                    editSelectedTask: $editSelectedTask,
                                    deleteSelectedTask: $deleteSelectedTask,
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
                // Keyboard shortcuts help
                if isTaskListFocused && selectedTaskId != nil {
                    Text("↑↓ Navigate • ⏎ Complete • ␣ Track • ⌘E Edit • ⌘⌫ Delete")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("⌘N Add • ⌘F Search")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
                
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
        .animation(.easeInOut(duration: 0.2), value: isSearchBarVisible)
        .onChange(of: isSearchFocused) { _, focused in
            if !focused && searchText.isEmpty && selectedFilter == .all &&
               selectedProjectFilter == nil && !showingFilters {
                showSearchBar = false
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($isTaskListFocused)
        .onKeyPress(.upArrow) {
            selectPreviousTask()
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectNextTask()
            return .handled
        }
        .onKeyPress(.return) {
            guard let taskId = selectedTaskId,
                  let task = filteredTasks.first(where: { $0.id == taskId }) else {
                return .ignored
            }
            completeTask(task)
            return .handled
        }
        .onKeyPress(.space) {
            guard let taskId = selectedTaskId,
                  let task = filteredTasks.first(where: { $0.id == taskId }) else {
                return .ignored
            }
            toggleTracking(for: task)
            return .handled
        }
        .onKeyPress(.escape) {
            selectedTaskId = nil
            isTaskListFocused = false
            return .handled
        }
        .background(
            // Hidden buttons for keyboard shortcuts
            Group {
                Button("") {
                    isInputFocused = true
                }
                .keyboardShortcut("n", modifiers: .command)
                .hidden()
                
                Button("") {
                    if let taskId = selectedTaskId {
                        editSelectedTask = taskId
                    }
                }
                .keyboardShortcut("e", modifiers: .command)
                .hidden()
                
                Button("") {
                    if let taskId = selectedTaskId {
                        deleteSelectedTask = taskId
                    }
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .hidden()
                
                Button("") {
                    showSearchBar = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isSearchFocused = true
                    }
                }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
            }
        )
    }
    
    // Search bar visibility: shown explicitly via ⌘F, or when it has content/filters
    private var isSearchBarVisible: Bool {
        showSearchBar || !searchText.isEmpty || showingFilters ||
        selectedFilter != .all || selectedProjectFilter != nil
    }
    
    // Keyboard navigation helpers
    @State private var editSelectedTask: UUID?
    @State private var deleteSelectedTask: UUID?
    
    private func selectNextTask() {
        let tasks = filteredTasks
        guard !tasks.isEmpty else { return }
        
        if let currentId = selectedTaskId,
           let currentIndex = tasks.firstIndex(where: { $0.id == currentId }) {
            let nextIndex = min(currentIndex + 1, tasks.count - 1)
            selectedTaskId = tasks[nextIndex].id
        } else {
            selectedTaskId = tasks.first?.id
        }
    }
    
    private func selectPreviousTask() {
        let tasks = filteredTasks
        guard !tasks.isEmpty else { return }
        
        if let currentId = selectedTaskId,
           let currentIndex = tasks.firstIndex(where: { $0.id == currentId }) {
            let prevIndex = max(currentIndex - 1, 0)
            selectedTaskId = tasks[prevIndex].id
        } else {
            selectedTaskId = tasks.last?.id
        }
    }
    
    private func toggleTracking(for task: TrackedTask) {
        if timeTrackingManager.isTaskActive(task) {
            timeTrackingManager.stopTracking(context: modelContext)
        } else {
            timeTrackingManager.startTracking(task: task, context: modelContext)
        }
    }
    
    private func completeTask(_ task: TrackedTask) {
        if timeTrackingManager.isTaskActive(task) {
            timeTrackingManager.stopTracking(context: modelContext)
        }
        
        let taskName = task.name
        task.isCompleted = true
        
        // Move selection to next task
        selectNextTask()
        
        // Show undo toast
        AppUndoManager.shared.showUndo(message: "Completed \"\(taskName)\"") {
            task.isCompleted = false
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
    
    private var filteredTasks: [TrackedTask] {
        var tasks = activeTasks
        
        // Apply search filter
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            tasks = tasks.filter { task in
                task.name.lowercased().contains(searchLower) ||
                (task.project?.name.lowercased().contains(searchLower) ?? false)
            }
        }
        
        // Apply project filter
        if let project = selectedProjectFilter {
            tasks = tasks.filter { $0.project?.id == project.id }
        }
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .todayTracked:
            let today = Calendar.current.startOfDay(for: Date())
            tasks = tasks.filter { task in
                task.timeEntries?.contains { entry in
                    Calendar.current.isDate(entry.startTime, inSameDayAs: today)
                } ?? false
            }
        case .hasTimeLeft:
            tasks = tasks.filter { $0.remainingSeconds > 0 }
        case .overTime:
            tasks = tasks.filter { $0.remainingSeconds <= 0 }
        }
        
        return tasks
    }
    
    private var filteredGroupedTasks: [String: [TrackedTask]] {
        var groups: [String: [TrackedTask]] = [:]
        for task in filteredTasks {
            let projectName = task.project?.name ?? "No Project"
            if groups[projectName] == nil {
                groups[projectName] = []
            }
            groups[projectName]?.append(task)
        }
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
        
        try? modelContext.save()
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
                let newProject = Project(name: projectName, colorHex: Project.colorPalette.randomElement() ?? "#007AFF")
                modelContext.insert(newProject)
                project = newProject
            }
        }
        
        // Calculate the next orderIndex (put new tasks at the top)
        let minOrderIndex = activeTasks.map(\.orderIndex).min() ?? 1
        
        let task = TrackedTask(
            name: parsed.taskName,
            estimatedSeconds: parsed.estimatedSeconds,
            project: project,
            orderIndex: minOrderIndex - 1
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
    @State private var selectedSuggestionIndex = 0
    
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
                    let suggestions = Array(suggestedProjects.prefix(5))
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, project in
                        Button(action: { applyProjectSuggestion(project) }) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(project.color)
                                    .frame(width: 8, height: 8)
                                Text(project.name)
                                    .font(.callout)
                                    .fontWeight(index == selectedSuggestionIndex ? .medium : .regular)
                                Spacer()
                                if index == selectedSuggestionIndex {
                                    Text("⏎")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            index == selectedSuggestionIndex
                                ? Color.accentColor.opacity(0.15)
                                : Color(nsColor: .controlBackgroundColor).opacity(0.8)
                        )
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
                        // Reset suggestion selection when text changes
                        selectedSuggestionIndex = 0
                    }
                    .onSubmit {
                        if showingSuggestions {
                            let suggestions = Array(suggestedProjects.prefix(5))
                            if !suggestions.isEmpty {
                                let safeIndex = min(selectedSuggestionIndex, suggestions.count - 1)
                                applyProjectSuggestion(suggestions[safeIndex])
                            }
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
    @Binding var selectedTaskId: UUID?
    @Binding var editSelectedTask: UUID?
    @Binding var deleteSelectedTask: UUID?
    let onReorder: (TrackedTask, TrackedTask) -> Void
    
    // Fluid drag reorder state
    @State private var dragSourceIndex: Int?
    @State private var dragCurrentIndex: Int?
    @State private var dragOffset: CGFloat = 0
    @State private var rowHeight: CGFloat = 56
    
    private let rowSpacing: CGFloat = 4
    
    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            Text(projectName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                let isDragging = dragSourceIndex == index
                
                TaskRowView(
                    task: task,
                    isKeyboardSelected: selectedTaskId == task.id,
                    shouldEdit: editSelectedTask == task.id,
                    shouldDelete: deleteSelectedTask == task.id,
                    onEditHandled: { editSelectedTask = nil },
                    onDeleteHandled: { deleteSelectedTask = nil }
                )
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: RowHeightKey.self, value: geo.size.height)
                    }
                )
                .offset(y: verticalOffset(for: index))
                .zIndex(isDragging ? 1 : 0)
                .scaleEffect(isDragging ? 1.03 : 1.0)
                .shadow(
                    color: isDragging ? Color.black.opacity(0.15) : Color.clear,
                    radius: isDragging ? 6 : 0,
                    y: isDragging ? 2 : 0
                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            handleDragChanged(index: index, task: task, translation: value.translation.height)
                        }
                        .onEnded { _ in
                            handleDragEnded()
                        }
                )
            }
            .onPreferenceChange(RowHeightKey.self) { height in
                if height > 0 { rowHeight = height }
            }
        }
    }
    
    // MARK: - Offset Calculation
    
    private func verticalOffset(for index: Int) -> CGFloat {
        guard let sourceIndex = dragSourceIndex else { return 0 }
        let targetIndex = dragCurrentIndex ?? sourceIndex
        
        // Dragged item follows the gesture directly
        if index == sourceIndex {
            return dragOffset
        }
        
        let shift = rowHeight + rowSpacing
        
        // Items between source and target shift to fill the gap
        if sourceIndex < targetIndex {
            // Dragging downward: items between source and target shift up
            if index > sourceIndex && index <= targetIndex {
                return -shift
            }
        } else if sourceIndex > targetIndex {
            // Dragging upward: items between target and source shift down
            if index >= targetIndex && index < sourceIndex {
                return shift
            }
        }
        
        return 0
    }
    
    // MARK: - Drag Handlers
    
    private func handleDragChanged(index: Int, task: TrackedTask, translation: CGFloat) {
        if dragSourceIndex == nil {
            withAnimation(.easeInOut(duration: 0.15)) {
                dragSourceIndex = index
                dragCurrentIndex = index
            }
            draggingTask = task
        }
        
        dragOffset = translation
        
        // Calculate which slot the dragged item is over
        let shift = rowHeight + rowSpacing
        guard shift > 0 else { return }
        let proposedShift = Int(round(translation / shift))
        let newIndex = max(0, min(tasks.count - 1, (dragSourceIndex ?? index) + proposedShift))
        
        if newIndex != dragCurrentIndex {
            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.8)) {
                dragCurrentIndex = newIndex
            }
        }
    }
    
    private func handleDragEnded() {
        let sourceIndex = dragSourceIndex
        let targetIndex = dragCurrentIndex
        
        withAnimation(.easeInOut(duration: 0.2)) {
            dragOffset = 0
            dragSourceIndex = nil
            dragCurrentIndex = nil
            draggingTask = nil
            
            if let sourceIndex, let targetIndex,
               sourceIndex != targetIndex,
               sourceIndex < tasks.count,
               targetIndex < tasks.count {
                onReorder(tasks[sourceIndex], tasks[targetIndex])
            }
        }
    }
}

// Preference key for measuring row height
private struct RowHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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

struct NoResultsView: View {
    let searchText: String
    let filter: TaskListView.TaskFilter
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            if !searchText.isEmpty {
                Text("No tasks matching \"\(searchText)\"")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                Text("No tasks match the current filter")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            
            Text("Try a different search or filter")
                .font(.caption)
                .foregroundStyle(Color.gray.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    TaskListView(onManageProjects: {})
        .modelContainer(for: [Project.self, TrackedTask.self, TimeEntry.self], inMemory: true)
        .environmentObject(TimeTrackingManager())
        .frame(width: 360, height: 500)
}

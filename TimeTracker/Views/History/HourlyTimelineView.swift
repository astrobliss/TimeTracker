import SwiftUI
import SwiftData

struct HourlyTimelineView: View {
    let date: Date
    let entries: [TimeEntry]
    var onDismiss: (() -> Void)?
    
    // Zoom levels: hours per screen
    @State private var zoomLevel: ZoomLevel = .normal
    
    enum ZoomLevel: String, CaseIterable {
        case compact = "Compact"
        case normal = "Normal"
        case expanded = "Expanded"
        
        var hourHeight: CGFloat {
            switch self {
            case .compact: return 40
            case .normal: return 60
            case .expanded: return 90
            }
        }
    }
    
    private var hourHeight: CGFloat {
        zoomLevel.hourHeight
    }
    
    // Dynamic time range based on entries
    private var displayStartHour: Int {
        guard !entries.isEmpty else { return 6 }
        let calendar = Calendar.current
        let earliestHour = entries.compactMap { calendar.component(.hour, from: $0.startTime) }.min() ?? 6
        // Round down to nearest even hour, minimum 0
        return max(0, (earliestHour / 2) * 2 - 2)
    }
    
    private var displayEndHour: Int {
        guard !entries.isEmpty else { return 22 }
        let calendar = Calendar.current
        let latestHour = entries.compactMap { entry -> Int in
            let endTime = entry.endTime ?? Date()
            return calendar.component(.hour, from: endTime)
        }.max() ?? 22
        // Round up to nearest even hour, maximum 24
        return min(24, ((latestHour + 2) / 2) * 2 + 2)
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    private var totalSeconds: Int {
        entries.reduce(0) { $0 + $1.durationSeconds }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateString)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if totalSeconds > 0 {
                        Text("Total: \(TimeFormatter.formatHoursMinutes(seconds: totalSeconds))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Zoom controls
                HStack(spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            zoomOut()
                        }
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .disabled(zoomLevel == .compact)
                    
                    Text(zoomLevel.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 60)
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            zoomIn()
                        }
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .disabled(zoomLevel == .expanded)
                }
                
                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 4)
                
                Button("Back") {
                    onDismiss?()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            
            // Time range indicator
            HStack {
                Text("Showing \(hourLabel(for: displayStartHour)) - \(hourLabel(for: displayEndHour))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 4)
            
            Divider()
            
            // Timeline
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Hour grid lines and labels
                    VStack(spacing: 0) {
                        ForEach(displayStartHour..<displayEndHour, id: \.self) { hour in
                            HStack(alignment: .top, spacing: 4) {
                                Text(hourLabel(for: hour))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, alignment: .trailing)
                                
                                VStack(spacing: 0) {
                                    Divider()
                                    Spacer()
                                }
                            }
                            .frame(height: hourHeight)
                        }
                        // Last hour label
                        HStack(alignment: .top, spacing: 4) {
                            Text(hourLabel(for: displayEndHour))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .trailing)
                            Divider()
                        }
                    }
                    
                    // Current time indicator (if viewing today)
                    if Calendar.current.isDateInToday(date) {
                        CurrentTimeIndicator(
                            displayStartHour: displayStartHour,
                            displayEndHour: displayEndHour,
                            hourHeight: hourHeight
                        )
                    }
                    
                    // Time entry blocks
                    GeometryReader { geometry in
                        let blockWidth = geometry.size.width - 60
                        ForEach(entries) { entry in
                            if let position = entryPosition(for: entry) {
                                TimelineEntryBlock(entry: entry)
                                    .frame(width: max(blockWidth, 100), height: max(position.height, 24))
                                    .offset(x: 52, y: position.yOffset)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func zoomIn() {
        switch zoomLevel {
        case .compact: zoomLevel = .normal
        case .normal: zoomLevel = .expanded
        case .expanded: break
        }
    }
    
    private func zoomOut() {
        switch zoomLevel {
        case .compact: break
        case .normal: zoomLevel = .compact
        case .expanded: zoomLevel = .normal
        }
    }
    
    private func hourLabel(for hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour % 24
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
    
    private func entryPosition(for entry: TimeEntry) -> (yOffset: CGFloat, height: CGFloat)? {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: entry.startTime)
        guard let startHourValue = startComponents.hour,
              let startMinute = startComponents.minute else { return nil }
        
        let endTime = entry.endTime ?? Date()
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        guard let endHourValue = endComponents.hour,
              let endMinute = endComponents.minute else { return nil }
        
        // Clamp to visible range
        let visibleStartHour = max(startHourValue, displayStartHour)
        let visibleStartMinute = startHourValue < displayStartHour ? 0 : startMinute
        let visibleEndHour = min(endHourValue, displayEndHour)
        let visibleEndMinute = endHourValue > displayEndHour ? 0 : endMinute
        
        // Check if entry is visible
        if visibleStartHour >= displayEndHour || visibleEndHour < displayStartHour {
            return nil
        }
        
        let startOffset = CGFloat(visibleStartHour - displayStartHour) * hourHeight + CGFloat(visibleStartMinute) / 60.0 * hourHeight
        let endOffset = CGFloat(visibleEndHour - displayStartHour) * hourHeight + CGFloat(visibleEndMinute) / 60.0 * hourHeight
        
        return (startOffset, endOffset - startOffset)
    }
}

// Current time indicator for today's view
struct CurrentTimeIndicator: View {
    let displayStartHour: Int
    let displayEndHour: Int
    let hourHeight: CGFloat
    
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    private var yOffset: CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        
        guard hour >= displayStartHour && hour < displayEndHour else { return -100 }
        
        return CGFloat(hour - displayStartHour) * hourHeight + CGFloat(minute) / 60.0 * hourHeight
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .offset(x: 44)
            
            Rectangle()
                .fill(.red.opacity(0.5))
                .frame(height: 1)
        }
        .offset(y: yOffset)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
}

struct TimelineEntryBlock: View {
    @Bindable var entry: TimeEntry
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var undoManager = AppUndoManager.shared
    
    @State private var showingPopover = false
    @State private var isEditing = false
    @State private var editStartTime: Date = Date()
    @State private var editEndTime: Date = Date()
    @State private var showingDeleteConfirmation = false
    
    private var projectColor: Color {
        entry.task?.project?.color ?? .gray
    }
    
    private var taskName: String {
        entry.task?.name ?? "Unknown Task"
    }
    
    private var projectName: String {
        entry.task?.project?.name ?? "No Project"
    }
    
    private var timeRange: String {
        entry.formattedTimeRange
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Color bar
            Rectangle()
                .fill(projectColor)
                .frame(width: 3)
            
            // Content
            VStack(alignment: .leading, spacing: 1) {
                Text(taskName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("\(projectName) • \(timeRange)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            
            Spacer(minLength: 0)
        }
        .background(projectColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(projectColor.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            showingPopover = true
        }
        .popover(isPresented: $showingPopover, arrowEdge: .trailing) {
            entryPopoverContent
        }
    }
    
    @ViewBuilder
    private var entryPopoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showingDeleteConfirmation {
                VStack(spacing: 8) {
                    Text("Delete this entry?")
                        .font(.callout)
                        .fontWeight(.medium)
                    
                    HStack {
                        Button("Cancel") {
                            showingDeleteConfirmation = false
                        }
                        .buttonStyle(.borderless)
                        
                        Button("Delete") {
                            deleteEntry()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding()
            } else if isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Edit Time Entry")
                        .font(.headline)
                    
                    HStack {
                        Text("Start:")
                            .font(.caption)
                            .frame(width: 40, alignment: .trailing)
                        DatePicker("", selection: $editStartTime, displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.field)
                    }
                    
                    HStack {
                        Text("End:")
                            .font(.caption)
                            .frame(width: 40, alignment: .trailing)
                        DatePicker("", selection: $editEndTime, displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.field)
                    }
                    
                    HStack {
                        Spacer()
                        Button("Cancel") {
                            isEditing = false
                        }
                        .buttonStyle(.borderless)
                        
                        Button("Save") {
                            saveEdit()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(editEndTime <= editStartTime)
                    }
                }
                .padding()
            } else {
                // Details view
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if let project = entry.task?.project {
                            Circle()
                                .fill(project.color)
                                .frame(width: 10, height: 10)
                        }
                        Text(taskName)
                            .font(.headline)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Label(projectName, systemImage: "folder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Label(timeRange, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Label(entry.formattedDuration, systemImage: "hourglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    HStack {
                        Button("Edit") {
                            editStartTime = entry.startTime
                            editEndTime = entry.endTime ?? Date()
                            isEditing = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Delete", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 200)
    }
    
    private func saveEdit() {
        entry.startTime = editStartTime
        entry.endTime = editEndTime
        try? modelContext.save()
        isEditing = false
        showingPopover = false
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
        showingPopover = false
        
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
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, TrackedTask.self, TimeEntry.self, configurations: config)
    
    let project1 = Project(name: "Work", colorHex: "#007AFF")
    let project2 = Project(name: "Personal", colorHex: "#FF6B6B")
    container.mainContext.insert(project1)
    container.mainContext.insert(project2)
    
    let task1 = TrackedTask(name: "Code review", estimatedSeconds: 3600, project: project1)
    let task2 = TrackedTask(name: "Exercise", estimatedSeconds: 3600, project: project2)
    container.mainContext.insert(task1)
    container.mainContext.insert(task2)
    
    var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    components.hour = 9
    components.minute = 0
    let start1 = Calendar.current.date(from: components)!
    
    let entry1 = TimeEntry(task: task1)
    entry1.startTime = start1
    entry1.endTime = start1.addingTimeInterval(5400) // 1.5 hours
    container.mainContext.insert(entry1)
    
    components.hour = 14
    let start2 = Calendar.current.date(from: components)!
    let entry2 = TimeEntry(task: task2)
    entry2.startTime = start2
    entry2.endTime = start2.addingTimeInterval(3600) // 1 hour
    container.mainContext.insert(entry2)
    
    return HourlyTimelineView(date: Date(), entries: [entry1, entry2], onDismiss: {})
        .modelContainer(container)
        .frame(width: 360, height: 500)
}

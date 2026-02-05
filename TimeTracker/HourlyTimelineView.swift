import SwiftUI
import SwiftData

struct HourlyTimelineView: View {
    let date: Date
    let entries: [TimeEntry]
    @Environment(\.dismiss) private var dismiss
    
    private let hourHeight: CGFloat = 60
    private let startHour = 6  // 6 AM
    private let endHour = 22   // 10 PM
    
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
                        .font(.headline)
                    if totalSeconds > 0 {
                        Text("Total: \(TimeFormatter.formatHoursMinutes(seconds: totalSeconds))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            // Timeline
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Hour grid lines and labels
                    VStack(spacing: 0) {
                        ForEach(startHour..<endHour, id: \.self) { hour in
                            HStack(alignment: .top, spacing: 8) {
                                Text(hourLabel(for: hour))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50, alignment: .trailing)
                                
                                VStack(spacing: 0) {
                                    Divider()
                                    Spacer()
                                }
                            }
                            .frame(height: hourHeight)
                        }
                        // Last hour label
                        HStack(alignment: .top, spacing: 8) {
                            Text(hourLabel(for: endHour))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .trailing)
                            Divider()
                        }
                    }
                    
                    // Time entry blocks
                    ForEach(entries) { entry in
                        if let position = entryPosition(for: entry) {
                            TimelineEntryBlock(entry: entry)
                                .frame(height: max(position.height, 20))
                                .offset(x: 66, y: position.yOffset)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
    
    private func hourLabel(for hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
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
        let visibleStartHour = max(startHourValue, startHour)
        let visibleStartMinute = startHourValue < startHour ? 0 : startMinute
        let visibleEndHour = min(endHourValue, endHour)
        let visibleEndMinute = endHourValue > endHour ? 0 : endMinute
        
        // Check if entry is visible
        if visibleStartHour >= endHour || visibleEndHour < startHour {
            return nil
        }
        
        let startOffset = CGFloat(visibleStartHour - startHour) * hourHeight + CGFloat(visibleStartMinute) / 60.0 * hourHeight
        let endOffset = CGFloat(visibleEndHour - startHour) * hourHeight + CGFloat(visibleEndMinute) / 60.0 * hourHeight
        
        return (startOffset, endOffset - startOffset)
    }
}

struct TimelineEntryBlock: View {
    let entry: TimeEntry
    
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
                .frame(width: 4)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(taskName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(projectName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    
                    Text(timeRange)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(projectColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(projectColor.opacity(0.3), lineWidth: 1)
        )
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
    
    return HourlyTimelineView(date: Date(), entries: [entry1, entry2])
        .modelContainer(container)
}

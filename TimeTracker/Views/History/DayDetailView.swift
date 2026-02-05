import SwiftUI
import SwiftData

struct DayDetailView: View {
    let date: Date
    let entries: [TimeEntry]
    
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
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            if entries.isEmpty {
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
}

struct TimeEntryRowView: View {
    let entry: TimeEntry
    
    var body: some View {
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
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
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

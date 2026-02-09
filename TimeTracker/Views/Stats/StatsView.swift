import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(sort: \TimeEntry.startTime, order: .reverse) private var allTimeEntries: [TimeEntry]
    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \TrackedTask.name) private var allTasks: [TrackedTask]
    
    @State private var selectedPeriod: StatsPeriod = .week
    
    enum StatsPeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case allTime = "All Time"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Period selector
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(StatsPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Total time card
                TotalTimeCard(totalSeconds: totalTrackedSeconds)
                
                // Time by project chart
                if !projectTimeData.isEmpty {
                    ProjectDistributionChart(data: projectTimeData)
                }
                
                // Daily breakdown chart
                if !dailyTimeData.isEmpty {
                    DailyTimeChart(data: dailyTimeData, period: selectedPeriod)
                }
                
                // Estimate accuracy
                EstimateAccuracyCard(tasks: tasksWithTracking)
                
                // Top tasks
                TopTasksCard(tasks: topTrackedTasks)
            }
            .padding()
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredEntries: [TimeEntry] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedPeriod {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return allTimeEntries.filter { $0.startTime >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return allTimeEntries.filter { $0.startTime >= monthAgo }
        case .allTime:
            return allTimeEntries
        }
    }
    
    private var totalTrackedSeconds: Int {
        filteredEntries.reduce(0) { $0 + $1.durationSeconds }
    }
    
    private var projectTimeData: [ProjectTimeData] {
        var data: [UUID: (name: String, color: Color, seconds: Int)] = [:]
        
        for entry in filteredEntries {
            if let project = entry.task?.project {
                let existing = data[project.id] ?? (project.name, project.color, 0)
                data[project.id] = (existing.name, existing.color, existing.seconds + entry.durationSeconds)
            } else {
                let noProjectId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
                let existing = data[noProjectId] ?? ("No Project", .gray, 0)
                data[noProjectId] = (existing.name, existing.color, existing.seconds + entry.durationSeconds)
            }
        }
        
        return data.map { ProjectTimeData(id: $0.key, name: $0.value.name, color: $0.value.color, seconds: $0.value.seconds) }
            .sorted { $0.seconds > $1.seconds }
    }
    
    private var dailyTimeData: [DailyTimeData] {
        let calendar = Calendar.current
        var dailyData: [Date: Int] = [:]
        
        // Initialize all days in period
        let days: Int
        switch selectedPeriod {
        case .week: days = 7
        case .month: days = 30
        case .allTime: days = 30 // Show last 30 days for all time
        }
        
        for i in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                let startOfDay = calendar.startOfDay(for: date)
                dailyData[startOfDay] = 0
            }
        }
        
        // Aggregate entries
        for entry in filteredEntries {
            let startOfDay = calendar.startOfDay(for: entry.startTime)
            dailyData[startOfDay, default: 0] += entry.durationSeconds
        }
        
        return dailyData.map { DailyTimeData(date: $0.key, seconds: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    private var tasksWithTracking: [TrackedTask] {
        allTasks.filter { ($0.timeEntries?.count ?? 0) > 0 }
    }
    
    private var topTrackedTasks: [TrackedTask] {
        let tasksWithTime = allTasks.filter { task in
            guard let entries = task.timeEntries else { return false }
            return entries.contains { entry in
                filteredEntries.contains { $0.id == entry.id }
            }
        }
        
        return Array(tasksWithTime.sorted { $0.totalTrackedSeconds > $1.totalTrackedSeconds }.prefix(5))
    }
}

// MARK: - Stats Data Models

struct ProjectTimeData: Identifiable {
    let id: UUID
    let name: String
    let color: Color
    let seconds: Int
    
    var formattedTime: String {
        TimeFormatter.formatHoursMinutes(seconds: seconds)
    }
}

struct DailyTimeData: Identifiable {
    let id = UUID()
    let date: Date
    let seconds: Int
    
    var hours: Double {
        Double(seconds) / 3600.0
    }
    
    var dayLabel: String {
        TimeFormatter.weekdayFormatter.string(from: date)
    }
}

// MARK: - Stats Components

struct TotalTimeCard: View {
    let totalSeconds: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Total Time Tracked")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(TimeFormatter.formatHoursMinutes(seconds: totalSeconds))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ProjectDistributionChart: View {
    let data: [ProjectTimeData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time by Project")
                .font(.headline)
            
            Chart(data) { item in
                SectorMark(
                    angle: .value("Time", item.seconds),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(item.color)
                .cornerRadius(4)
            }
            .frame(height: 150)
            
            // Legend
            VStack(alignment: .leading, spacing: 4) {
                ForEach(data.prefix(5)) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 8, height: 8)
                        
                        Text(item.name)
                            .font(.caption)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(item.formattedTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct DailyTimeChart: View {
    let data: [DailyTimeData]
    let period: StatsView.StatsPeriod
    
    private var maxHours: Double {
        max(data.map(\.hours).max() ?? 1, 1)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Activity")
                .font(.headline)
            
            Chart(data) { item in
                BarMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Hours", item.hours)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(4)
            }
            .chartYScale(domain: 0...maxHours)
            .chartXAxis {
                if period == .week {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                } else {
                    AxisMarks(values: .automatic)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let hours = value.as(Double.self) {
                            Text("\(Int(hours))h")
                        }
                    }
                }
            }
            .frame(height: 120)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct EstimateAccuracyCard: View {
    let tasks: [TrackedTask]
    
    private var averageAccuracy: Double {
        guard !tasks.isEmpty else { return 0 }
        
        let accuracies = tasks.compactMap { task -> Double? in
            guard task.estimatedSeconds > 0, task.totalTrackedSeconds > 0 else { return nil }
            let ratio = Double(task.totalTrackedSeconds) / Double(task.estimatedSeconds)
            // Cap at 200% to avoid outliers skewing the average
            return min(ratio, 2.0)
        }
        
        guard !accuracies.isEmpty else { return 0 }
        return accuracies.reduce(0, +) / Double(accuracies.count)
    }
    
    private var accuracyColor: Color {
        if averageAccuracy < 0.8 { return .green }
        if averageAccuracy <= 1.2 { return .blue }
        return .orange
    }
    
    private var accuracyText: String {
        if averageAccuracy < 0.8 { return "Under-estimating" }
        if averageAccuracy <= 1.2 { return "On target" }
        return "Over-running"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estimate Accuracy")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(averageAccuracy * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(accuracyColor)
                    
                    Text(accuracyText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Visual indicator
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    
                    Circle()
                        .trim(from: 0, to: min(averageAccuracy, 2.0) / 2.0)
                        .stroke(accuracyColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 60, height: 60)
            }
            
            Text("Based on \(tasks.count) completed task\(tasks.count == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct TopTasksCard: View {
    let tasks: [TrackedTask]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most Tracked Tasks")
                .font(.headline)
            
            if tasks.isEmpty {
                Text("No tracked tasks yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(tasks) { task in
                    HStack {
                        if let project = task.project {
                            Circle()
                                .fill(project.color)
                                .frame(width: 8, height: 8)
                        }
                        
                        Text(task.name)
                            .font(.caption)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(task.formattedTracked)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

#Preview("Stats") {
    StatsView()
        .modelContainer(for: [Project.self, TrackedTask.self, TimeEntry.self], inMemory: true)
        .frame(width: 360, height: 500)
}

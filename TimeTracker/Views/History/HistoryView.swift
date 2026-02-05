import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimeEntry.startTime, order: .reverse) private var allTimeEntries: [TimeEntry]
    
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var showTimeline = false
    @State private var timelineDate = Date()
    
    var body: some View {
        ZStack {
            if showTimeline {
                HourlyTimelineView(
                    date: timelineDate,
                    entries: entriesForTimelineDate,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showTimeline = false
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                VStack(spacing: 0) {
                    // Calendar
                    CalendarGridView(
                        currentMonth: $currentMonth,
                        selectedDate: $selectedDate,
                        timeEntries: allTimeEntries,
                        onDoubleClick: { date in
                            timelineDate = date
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showTimeline = true
                            }
                        }
                    )
                    
                    Divider()
                    
                    // Day detail
                    DayDetailView(
                        date: selectedDate,
                        entries: entriesForSelectedDate
                    )
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .clipped()
    }
    
    private var entriesForSelectedDate: [TimeEntry] {
        allTimeEntries.filter { entry in
            Calendar.current.isDate(entry.startTime, inSameDayAs: selectedDate)
        }
    }
    
    private var entriesForTimelineDate: [TimeEntry] {
        allTimeEntries.filter { entry in
            Calendar.current.isDate(entry.startTime, inSameDayAs: timelineDate)
        }
    }
}

struct CalendarGridView: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    let timeEntries: [TimeEntry]
    var onDoubleClick: ((Date) -> Void)?
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(spacing: 8) {
            // Month navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text(monthYearString)
                    .font(.headline)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                
                Button("Today") {
                    currentMonth = Date()
                    selectedDate = Date()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding(.horizontal)
            
            // Day headers
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            let days = daysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { day in
                    CalendarDayCell(
                        day: day,
                        currentMonth: currentMonth,
                        selectedDate: selectedDate,
                        hasEntries: hasEntries(for: day),
                        totalMinutes: totalMinutes(for: day)
                    )
                    .onTapGesture(count: 2) {
                        if calendar.isDate(day, equalTo: currentMonth, toGranularity: .month) {
                            selectedDate = day
                            onDoubleClick?(day)
                        }
                    }
                    .onTapGesture {
                        if calendar.isDate(day, equalTo: currentMonth, toGranularity: .month) {
                            selectedDate = day
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    private func previousMonth() {
        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }
    
    private func nextMonth() {
        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }
    
    private func daysInMonth() -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1)) else {
            return []
        }
        
        let startDate = monthFirstWeek.start
        let endDate = monthLastWeek.end
        var dates: [Date] = []
        
        // Generate only the weeks that contain days from this month
        var currentDate = startDate
        while currentDate < endDate {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dates
    }
    
    private func hasEntries(for date: Date) -> Bool {
        timeEntries.contains { calendar.isDate($0.startTime, inSameDayAs: date) }
    }
    
    private func totalMinutes(for date: Date) -> Int {
        let dayEntries = timeEntries.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
        let totalSeconds = dayEntries.reduce(0) { $0 + $1.durationSeconds }
        return totalSeconds / 60
    }
}

struct CalendarDayCell: View {
    let day: Date
    let currentMonth: Date
    let selectedDate: Date
    let hasEntries: Bool
    let totalMinutes: Int
    
    private let calendar = Calendar.current
    
    private var isCurrentMonth: Bool {
        calendar.isDate(day, equalTo: currentMonth, toGranularity: .month)
    }
    
    private var isSelected: Bool {
        calendar.isDate(day, inSameDayAs: selectedDate)
    }
    
    private var isToday: Bool {
        calendar.isDateInToday(day)
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 12))
                .foregroundStyle(isCurrentMonth ? (isToday ? Color.blue : Color.primary) : Color.gray.opacity(0.4))
            
            // Activity indicator
            if hasEntries && isCurrentMonth {
                Circle()
                    .fill(activityColor)
                    .frame(width: 6, height: 6)
            } else {
                Circle()
                    .fill(.clear)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(height: 36)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected && isCurrentMonth ? Color.accentColor.opacity(0.2) : .clear)
        )
    }
    
    private var activityColor: Color {
        // Intensity based on time tracked
        if totalMinutes > 240 { return .green }
        if totalMinutes > 120 { return .blue }
        if totalMinutes > 30 { return .orange }
        return .gray
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [Project.self, TrackedTask.self, TimeEntry.self], inMemory: true)
        .frame(height: 500)
}

// MARK: - Stats View

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
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
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

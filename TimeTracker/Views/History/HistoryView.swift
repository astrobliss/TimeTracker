import SwiftUI
import SwiftData

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

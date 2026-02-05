import Foundation
import SwiftData

@Model
final class TimeEntry {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    
    var task: TrackedTask?
    
    init(task: TrackedTask? = nil) {
        self.id = UUID()
        self.startTime = Date()
        self.endTime = nil
        self.task = task
    }
    
    var isRunning: Bool {
        endTime == nil
    }
    
    var durationSeconds: Int {
        let end = endTime ?? Date()
        return Int(end.timeIntervalSince(startTime))
    }
    
    func stop() {
        if endTime == nil {
            endTime = Date()
        }
    }
    
    var formattedDuration: String {
        TimeFormatter.format(seconds: durationSeconds)
    }
    
    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let start = formatter.string(from: startTime)
        if let end = endTime {
            return "\(start) - \(formatter.string(from: end))"
        }
        return "\(start) - now"
    }
}

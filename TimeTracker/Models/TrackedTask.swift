import Foundation
import SwiftData

@Model
final class TrackedTask {
    var id: UUID
    var name: String
    var estimatedSeconds: Int
    var createdAt: Date
    var isCompleted: Bool
    var orderIndex: Int
    
    var project: Project?
    
    @Relationship(deleteRule: .cascade, inverse: \TimeEntry.task)
    var timeEntries: [TimeEntry]?
    
    init(name: String, estimatedSeconds: Int, project: Project? = nil, orderIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.estimatedSeconds = estimatedSeconds
        self.createdAt = Date()
        self.isCompleted = false
        self.orderIndex = orderIndex
        self.project = project
        self.timeEntries = []
    }
    
    var totalTrackedSeconds: Int {
        timeEntries?.reduce(0) { $0 + $1.durationSeconds } ?? 0
    }
    
    var remainingSeconds: Int {
        estimatedSeconds - totalTrackedSeconds
    }
    
    var formattedEstimate: String {
        TimeFormatter.format(seconds: estimatedSeconds)
    }
    
    var formattedTracked: String {
        TimeFormatter.format(seconds: totalTrackedSeconds)
    }
    
    var formattedRemaining: String {
        TimeFormatter.format(seconds: remainingSeconds, showSign: true)
    }
}

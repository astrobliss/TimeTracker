import Foundation
import SwiftUI
import Combine

@MainActor
class TimeTrackingManager: ObservableObject {
    @Published var activeTask: TrackedTask?
    @Published var activeTimeEntry: TimeEntry?
    @Published var elapsedSeconds: Int = 0
    @Published var remainingSeconds: Int?
    
    private var timer: AnyCancellable?
    private var startTime: Date?
    
    var isTracking: Bool {
        activeTask != nil
    }
    
    func startTracking(task: TrackedTask, context: ModelContext) {
        // Stop any existing tracking
        if let _ = activeTask {
            stopTracking(context: context)
        }
        
        // Create new time entry
        let entry = TimeEntry(task: task)
        context.insert(entry)
        
        activeTask = task
        activeTimeEntry = entry
        startTime = Date()
        elapsedSeconds = 0
        
        updateRemainingTime()
        startTimer()
        
        try? context.save()
    }
    
    func stopTracking(context: ModelContext) {
        timer?.cancel()
        timer = nil
        
        activeTimeEntry?.stop()
        
        activeTask = nil
        activeTimeEntry = nil
        startTime = nil
        elapsedSeconds = 0
        remainingSeconds = nil
        
        try? context.save()
    }
    
    private func startTimer() {
        // Use tolerance to allow timer coalescing, reducing CPU wakes significantly
        timer = Timer.publish(every: 1, tolerance: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    private func tick() {
        guard let startTime = startTime else { return }
        elapsedSeconds = Int(Date().timeIntervalSince(startTime))
        updateRemainingTime()
    }
    
    private func updateRemainingTime() {
        guard let task = activeTask else {
            remainingSeconds = nil
            return
        }
        
        let previouslyTracked = task.totalTrackedSeconds - (activeTimeEntry?.durationSeconds ?? 0)
        let totalTracked = previouslyTracked + elapsedSeconds
        remainingSeconds = task.estimatedSeconds - totalTracked
    }
    
    func isTaskActive(_ task: TrackedTask) -> Bool {
        activeTask?.id == task.id
    }
}

import SwiftData

extension ModelContext {
    @MainActor
    static var preview: ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Project.self, TrackedTask.self, TimeEntry.self, configurations: config)
        return container.mainContext
    }
}

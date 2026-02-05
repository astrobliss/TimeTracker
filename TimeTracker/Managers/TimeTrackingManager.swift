import Foundation
import SwiftUI
import Combine
import UserNotifications

@MainActor
class TimeTrackingManager: ObservableObject {
    @Published var activeTask: TrackedTask?
    @Published var activeTimeEntry: TimeEntry?
    @Published var elapsedSeconds: Int = 0
    @Published var remainingSeconds: Int?
    
    // Notification settings
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        }
    }
    @Published var warningThresholdMinutes: Int {
        didSet {
            UserDefaults.standard.set(warningThresholdMinutes, forKey: "warningThresholdMinutes")
        }
    }
    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        }
    }
    
    private var timer: AnyCancellable?
    private var startTime: Date?
    private var hasSentWarningNotification = false
    private var hasSentExpiredNotification = false
    
    var isTracking: Bool {
        activeTask != nil
    }
    
    init() {
        self.notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.warningThresholdMinutes = UserDefaults.standard.object(forKey: "warningThresholdMinutes") as? Int ?? 5
        self.soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        
        requestNotificationPermission()
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
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
        
        // Reset notification flags
        hasSentWarningNotification = false
        hasSentExpiredNotification = false
        
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
        checkAndSendNotifications()
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
    
    private func checkAndSendNotifications() {
        guard notificationsEnabled, let remaining = remainingSeconds, let task = activeTask else { return }
        
        let warningThresholdSeconds = warningThresholdMinutes * 60
        
        // Send warning notification when reaching threshold
        if !hasSentWarningNotification && remaining <= warningThresholdSeconds && remaining > 0 {
            hasSentWarningNotification = true
            sendNotification(
                title: "Time Running Low",
                body: "\(task.name): \(warningThresholdMinutes) minute\(warningThresholdMinutes == 1 ? "" : "s") remaining",
                identifier: "warning-\(task.id.uuidString)"
            )
        }
        
        // Send expired notification when timer reaches zero
        if !hasSentExpiredNotification && remaining <= 0 {
            hasSentExpiredNotification = true
            sendNotification(
                title: "Time's Up!",
                body: "\(task.name): Estimated time has been exceeded",
                identifier: "expired-\(task.id.uuidString)"
            )
        }
    }
    
    private func sendNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        
        if soundEnabled {
            content.sound = .default
        }
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
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

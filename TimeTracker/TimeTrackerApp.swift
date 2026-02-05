import SwiftUI
import SwiftData

@main
struct TimeTrackerApp: App {
    let modelContainer: ModelContainer
    @StateObject private var timeTrackingManager = TimeTrackingManager()
    
    init() {
        let schema = Schema([
            Project.self,
            TrackedTask.self,
            TimeEntry.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Schema mismatch - delete old store and retry (development only)
            print("Failed to load ModelContainer: \(error). Attempting to delete old store...")
            
            // Delete the default store files
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let storeURL = appSupport.appendingPathComponent("default.store")
            
            for suffix in ["", "-shm", "-wal"] {
                let fileURL = storeURL.appendingPathExtension(suffix.isEmpty ? "" : String(suffix.dropFirst()))
                let urlToDelete = suffix.isEmpty ? storeURL : URL(fileURLWithPath: storeURL.path + suffix)
                try? FileManager.default.removeItem(at: urlToDelete)
            }
            
            // Retry after deletion
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("Successfully recreated ModelContainer after deleting old store.")
            } catch {
                fatalError("Could not initialize ModelContainer even after deleting old store: \(error)")
            }
        }
    }
    
    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .modelContainer(modelContainer)
                .environmentObject(timeTrackingManager)
        } label: {
            MenuBarLabel(timeTrackingManager: timeTrackingManager)
        }
        .menuBarExtraStyle(.window)
        .commandsRemoved()
    }
}

// MARK: - Keyboard Shortcut Modifiers

struct KeyboardShortcuts {
    static let addTask = KeyboardShortcut("n", modifiers: .command)
    static let stopTracking = KeyboardShortcut(".", modifiers: .command)
    static let switchToTasks = KeyboardShortcut("1", modifiers: .command)
    static let switchToHistory = KeyboardShortcut("2", modifiers: .command)
}

struct MenuBarLabel: View {
    @ObservedObject var timeTrackingManager: TimeTrackingManager
    
    var body: some View {
        if let remainingSeconds = timeTrackingManager.remainingSeconds {
            Text(formatMenuBarTime(remainingSeconds))
                .monospacedDigit()
        } else {
            Image(systemName: "timer")
        }
    }
    
    private func formatMenuBarTime(_ seconds: Int) -> String {
        let absSeconds = abs(seconds)
        let minutes = absSeconds / 60
        let secs = absSeconds % 60
        let sign = seconds < 0 ? "-" : ""
        return String(format: "%@%d:%02d", sign, minutes, secs)
    }
}

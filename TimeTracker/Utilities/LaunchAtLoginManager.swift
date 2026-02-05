import Foundation
import ServiceManagement

/// Manages the app's launch at login state using SMAppService (macOS 13+)
@MainActor
class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()
    
    @Published private(set) var isEnabled: Bool = false
    
    private init() {
        updateStatus()
    }
    
    /// Updates the published status from the system
    func updateStatus() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
    
    /// Toggles the launch at login state
    func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }
    
    /// Enables launch at login
    func enable() {
        do {
            try SMAppService.mainApp.register()
            updateStatus()
        } catch {
            print("Failed to enable launch at login: \(error.localizedDescription)")
        }
    }
    
    /// Disables launch at login
    func disable() {
        do {
            try SMAppService.mainApp.unregister()
            updateStatus()
        } catch {
            print("Failed to disable launch at login: \(error.localizedDescription)")
        }
    }
}

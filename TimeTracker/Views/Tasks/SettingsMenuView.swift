import SwiftUI
import AppKit

struct SettingsMenuView: View {
    @StateObject private var launchAtLogin = LaunchAtLoginManager.shared
    @EnvironmentObject private var timeTrackingManager: TimeTrackingManager
    
    var body: some View {
        Menu {
            Toggle("Launch at Login", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { _ in launchAtLogin.toggle() }
            ))
            
            Divider()
            
            // Notification settings
            Toggle("Timer Notifications", isOn: $timeTrackingManager.notificationsEnabled)
            
            if timeTrackingManager.notificationsEnabled {
                Toggle("Notification Sound", isOn: $timeTrackingManager.soundEnabled)
                
                Menu("Warning at...") {
                    ForEach([1, 2, 5, 10, 15], id: \.self) { minutes in
                        Button {
                            timeTrackingManager.warningThresholdMinutes = minutes
                        } label: {
                            HStack {
                                Text("\(minutes) minute\(minutes == 1 ? "" : "s")")
                                if timeTrackingManager.warningThresholdMinutes == minutes {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            Button("Quit Time Tracker") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            Image(systemName: "gearshape")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

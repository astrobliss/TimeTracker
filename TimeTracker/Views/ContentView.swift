import SwiftUI
import SwiftData

enum NavigationScreen: Equatable {
    case main
    case projectManager
    case editProject(Project)
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var timeTrackingManager: TimeTrackingManager
    @State private var selectedTab = 0
    @State private var currentScreen: NavigationScreen = .main
    
    var body: some View {
        VStack(spacing: 0) {
            switch currentScreen {
            case .main:
                mainView
            case .projectManager:
                ProjectManagerView(
                    onDismiss: { currentScreen = .main },
                    onEditProject: { project in currentScreen = .editProject(project) }
                )
            case .editProject(let project):
                ProjectEditView(
                    project: project,
                    onDismiss: { currentScreen = .projectManager }
                )
            }
        }
        .frame(width: 360, height: 500)
        .background(
            // Hidden buttons for keyboard shortcuts
            Group {
                Button("") { selectedTab = 0 }
                    .keyboardShortcut("1", modifiers: .command)
                    .hidden()
                
                Button("") { selectedTab = 1 }
                    .keyboardShortcut("2", modifiers: .command)
                    .hidden()
                
                Button("") {
                    if timeTrackingManager.isTracking {
                        timeTrackingManager.stopTracking(context: modelContext)
                    }
                }
                .keyboardShortcut(".", modifiers: .command)
                .hidden()
                
                Button("") {
                    if currentScreen != .main {
                        currentScreen = .main
                    }
                }
                .keyboardShortcut(.escape, modifiers: [])
                .hidden()
            }
        )
    }
    
    private var mainView: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("Tasks").tag(0)
                Text("History").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            // Content
            switch selectedTab {
            case 0:
                TaskListView(
                    onManageProjects: { currentScreen = .projectManager }
                )
            case 1:
                HistoryView()
            default:
                TaskListView(
                    onManageProjects: { currentScreen = .projectManager }
                )
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, TrackedTask.self, TimeEntry.self], inMemory: true)
        .environmentObject(TimeTrackingManager())
}

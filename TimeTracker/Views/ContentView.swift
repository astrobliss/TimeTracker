import SwiftUI
import SwiftData

enum NavigationScreen: Equatable {
    case main
    case projectManager
    case editProject(Project)
}

// MARK: - Undo Manager

/// Manages undo operations with toast notifications
@MainActor
class AppUndoManager: ObservableObject {
    static let shared = AppUndoManager()
    
    @Published var currentToast: UndoToast?
    
    private var undoTimer: Timer?
    private let undoGracePeriod: TimeInterval = 5.0
    
    struct UndoToast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let undoAction: () -> Void
        
        static func == (lhs: UndoToast, rhs: UndoToast) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    private init() {}
    
    /// Show an undo toast with a message and undo action
    func showUndo(message: String, undoAction: @escaping () -> Void) {
        // Cancel any existing undo timer
        undoTimer?.invalidate()
        
        // Show the toast
        withAnimation(.easeInOut(duration: 0.2)) {
            currentToast = UndoToast(message: message, undoAction: undoAction)
        }
        
        // Auto-dismiss after grace period
        undoTimer = Timer.scheduledTimer(withTimeInterval: undoGracePeriod, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismissToast()
            }
        }
    }
    
    /// Perform undo action
    func performUndo() {
        undoTimer?.invalidate()
        undoTimer = nil
        
        currentToast?.undoAction()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            currentToast = nil
        }
    }
    
    /// Dismiss toast without undoing
    func dismissToast() {
        undoTimer?.invalidate()
        undoTimer = nil
        
        withAnimation(.easeInOut(duration: 0.2)) {
            currentToast = nil
        }
    }
}

// MARK: - Toast View

struct UndoToastView: View {
    @ObservedObject var undoManager: AppUndoManager
    
    var body: some View {
        if let toast = undoManager.currentToast {
            HStack(spacing: 12) {
                Text(toast.message)
                    .font(.callout)
                    .lineLimit(1)
                
                Button("Undo") {
                    undoManager.performUndo()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button {
                    undoManager.dismissToast()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - View Modifier

struct UndoToastModifier: ViewModifier {
    @StateObject private var undoManager = AppUndoManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                UndoToastView(undoManager: undoManager)
                    .padding(.bottom, 16)
            }
    }
}

extension View {
    func withUndoToast() -> some View {
        modifier(UndoToastModifier())
    }
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
        .withUndoToast()
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
                
                Button("") { selectedTab = 2 }
                    .keyboardShortcut("3", modifiers: .command)
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
                Text("Stats").tag(2)
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
            case 2:
                StatsView()
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

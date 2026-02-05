import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Project.name) private var projects: [Project]
    
    let onDismiss: () -> Void
    
    @State private var taskName = ""
    @State private var estimatedHours = 0
    @State private var estimatedMinutes = 30
    @State private var selectedProject: Project?
    @State private var showingNewProject = false
    @State private var newProjectName = ""
    @State private var newProjectColor = "#007AFF"
    
    private let colorOptions = [
        "#FF5733", "#FF8C00", "#FFD700",
        "#32CD32", "#007AFF", "#5856D6",
        "#AF52DE", "#FF2D55", "#8E8E93"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text("New Task")
                    .font(.headline)
                
                Spacer()
                
                Button("Add") {
                    addTask()
                }
                .buttonStyle(.borderedProminent)
                .disabled(taskName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            
            Divider()
            
            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Task name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Task Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("What are you working on?", text: $taskName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Time estimate
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Time Estimate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Picker("Hours", selection: $estimatedHours) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text("\(hour)h").tag(hour)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 70)
                            
                            Picker("Minutes", selection: $estimatedMinutes) {
                                ForEach([0, 5, 10, 15, 20, 25, 30, 45], id: \.self) { minute in
                                    Text("\(minute)m").tag(minute)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 70)
                            
                            Spacer()
                            
                            Text(formattedEstimate)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    
                    // Project selection
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Project")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Picker("Project", selection: $selectedProject) {
                            Text("No Project").tag(nil as Project?)
                            
                            ForEach(projects) { project in
                                HStack {
                                    Circle()
                                        .fill(project.color)
                                        .frame(width: 8, height: 8)
                                    Text(project.name)
                                }
                                .tag(project as Project?)
                            }
                        }
                        .labelsHidden()
                    }
                    
                    // Quick create project
                    if !showingNewProject {
                        Button(action: { showingNewProject = true }) {
                            Label("Create New Project", systemImage: "plus.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("New Project")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextField("Project name", text: $newProjectName)
                                .textFieldStyle(.roundedBorder)
                            
                            // Color picker
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(28)), count: 9), spacing: 6) {
                                ForEach(colorOptions, id: \.self) { hex in
                                    Circle()
                                        .fill(Color(hex: hex) ?? .blue)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: newProjectColor == hex ? 2 : 0)
                                        )
                                        .onTapGesture {
                                            newProjectColor = hex
                                        }
                                }
                            }
                            
                            HStack {
                                Button("Cancel") {
                                    showingNewProject = false
                                    newProjectName = ""
                                }
                                .buttonStyle(.borderless)
                                
                                Button("Create") {
                                    createProject()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
    }
    
    private var formattedEstimate: String {
        let totalSeconds = TimeFormatter.parse(hours: estimatedHours, minutes: estimatedMinutes)
        return TimeFormatter.format(seconds: totalSeconds)
    }
    
    private func addTask() {
        let totalSeconds = TimeFormatter.parse(hours: estimatedHours, minutes: estimatedMinutes)
        let task = TrackedTask(
            name: taskName.trimmingCharacters(in: .whitespaces),
            estimatedSeconds: totalSeconds,
            project: selectedProject
        )
        modelContext.insert(task)
        onDismiss()
    }
    
    private func createProject() {
        let project = Project(
            name: newProjectName.trimmingCharacters(in: .whitespaces),
            colorHex: newProjectColor
        )
        modelContext.insert(project)
        selectedProject = project
        showingNewProject = false
        newProjectName = ""
    }
}

#Preview {
    AddTaskView(onDismiss: {})
        .modelContainer(for: [Project.self, TrackedTask.self, TimeEntry.self], inMemory: true)
        .frame(width: 360, height: 500)
}

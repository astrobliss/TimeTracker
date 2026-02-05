import SwiftUI
import SwiftData

struct ProjectManagerView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Project.name) private var projects: [Project]
    
    let onDismiss: () -> Void
    let onEditProject: (Project) -> Void
    
    @State private var showingAddProject = false
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
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text("Projects")
                    .font(.headline)
                
                Spacer()
                
                // Spacer to balance
                Color.clear.frame(width: 60)
            }
            .padding()
            
            Divider()
            
            // Project list
            if projects.isEmpty && !showingAddProject {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    
                    Text("No projects yet")
                        .foregroundStyle(.secondary)
                    
                    Button("Create your first project") {
                        showingAddProject = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(projects) { project in
                            ProjectRowView(
                                project: project,
                                onEdit: { onEditProject(project) },
                                onDelete: { deleteProject(project) }
                            )
                        }
                        
                        // Add project inline
                        if showingAddProject {
                            VStack(alignment: .leading, spacing: 8) {
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
                                        showingAddProject = false
                                        newProjectName = ""
                                    }
                                    .buttonStyle(.borderless)
                                    
                                    Spacer()
                                    
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
            
            if !projects.isEmpty || showingAddProject {
                Divider()
                
                // Add button
                HStack {
                    Spacer()
                    
                    Button(action: { showingAddProject = true }) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Project")
                    }
                    .buttonStyle(.borderless)
                    .disabled(showingAddProject)
                }
                .padding()
            }
        }
    }
    
    private func createProject() {
        let project = Project(
            name: newProjectName.trimmingCharacters(in: .whitespaces),
            colorHex: newProjectColor
        )
        modelContext.insert(project)
        showingAddProject = false
        newProjectName = ""
    }
    
    private func deleteProject(_ project: Project) {
        modelContext.delete(project)
    }
}

struct ProjectRowView: View {
    let project: Project
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            if showingDeleteConfirmation {
                // Inline delete confirmation
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete \"\(project.name)\"?")
                            .font(.callout)
                            .fontWeight(.medium)
                        Text("All tasks will be deleted")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Cancel") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showingDeleteConfirmation = false
                        }
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    
                    Button("Delete") {
                        onDelete()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            } else {
                HStack(spacing: 12) {
                    Circle()
                        .fill(project.color)
                        .frame(width: 12, height: 12)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name)
                            .font(.body)
                        
                        Text("\(project.tasks?.count ?? 0) tasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showingDeleteConfirmation = true
                        }
                    }) {
                        Image(systemName: "trash.circle")
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.borderless)
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }
}

struct ProjectEditView: View {
    @Environment(\.modelContext) private var modelContext
    
    let project: Project?
    let onDismiss: () -> Void
    
    @State private var projectName = ""
    @State private var selectedColor = "#007AFF"
    
    private let colorOptions = [
        "#FF5733", "#FF8C00", "#FFD700",
        "#32CD32", "#007AFF", "#5856D6",
        "#AF52DE", "#FF2D55", "#8E8E93"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text("Edit Project")
                    .font(.headline)
                
                Spacer()
                
                Button("Save") {
                    saveProject()
                }
                .buttonStyle(.borderedProminent)
                .disabled(projectName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            
            Divider()
            
            // Form
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Project Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("Project name", text: $projectName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(36)), count: 6), spacing: 8) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .blue)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == hex ? 2 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = hex
                                }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            if let project = project {
                projectName = project.name
                selectedColor = project.colorHex
            }
        }
    }
    
    private func saveProject() {
        if let project = project {
            project.name = projectName.trimmingCharacters(in: .whitespaces)
            project.colorHex = selectedColor
        }
        onDismiss()
    }
}

#Preview {
    ProjectManagerView(onDismiss: {}, onEditProject: { _ in })
        .modelContainer(for: [Project.self, TrackedTask.self, TimeEntry.self], inMemory: true)
        .frame(width: 360, height: 500)
}

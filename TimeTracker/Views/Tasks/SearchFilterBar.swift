import SwiftUI

struct SearchFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedFilter: TaskListView.TaskFilter
    @Binding var selectedProject: Project?
    let projects: [Project]
    @Binding var showingFilters: Bool
    var isSearchFocused: FocusState<Bool>.Binding
    
    private var hasActiveFilters: Bool {
        selectedFilter != .all || selectedProject != nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                
                TextField("Search tasks...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused(isSearchFocused)
                    .onSubmit {
                        // Dismiss search focus on Enter so user can navigate tasks
                        isSearchFocused.wrappedValue = false
                    }
                    .onExitCommand {
                        // Escape clears search and dismisses
                        searchText = ""
                        selectedFilter = .all
                        selectedProject = nil
                        showingFilters = false
                        isSearchFocused.wrappedValue = false
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
                
                // Close button to dismiss search bar
                Button {
                    searchText = ""
                    selectedFilter = .all
                    selectedProject = nil
                    showingFilters = false
                    isSearchFocused.wrappedValue = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.borderless)
                .help("Close search (Esc)")
                
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showingFilters.toggle()
                    }
                } label: {
                    Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .foregroundStyle(hasActiveFilters ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help("Filter tasks")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            // Filter options
            if showingFilters {
                VStack(spacing: 8) {
                    // Status filter
                    HStack {
                        Text("Status:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Picker("Filter", selection: $selectedFilter) {
                            ForEach(TaskListView.TaskFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    
                    // Project filter
                    HStack {
                        Text("Project:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Picker("Project", selection: $selectedProject) {
                            Text("All Projects").tag(nil as Project?)
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
                        
                        Spacer()
                        
                        if hasActiveFilters {
                            Button("Clear") {
                                selectedFilter = .all
                                selectedProject = nil
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.bottom, 4)
    }
}

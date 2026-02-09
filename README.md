# Time Tracker

A native macOS menu bar application for tracking time spent on tasks, built with SwiftUI and SwiftData.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![License](https://img.shields.io/badge/License-MIT-green)

<p align="center">
  <img src="screenshots/app-preview.png" alt="Time Tracker Preview" width="360">
</p>

## Features

- **Menu Bar Integration** — Lives unobtrusively in your menu bar, showing a timer icon when idle or a live countdown when tracking
- **Task Management** — Create tasks with time estimates, organized by color-coded projects
- **Real-time Tracking** — Start/stop tracking with a single click and watch your remaining time count down
- **Over-time Alerts** — When you exceed your estimate, the timer displays negative time in red
- **Project Organization** — Group tasks by projects with custom colors for visual organization
- **Historical Calendar** — View your tracked time history on a calendar with day-by-day breakdowns and hourly timeline views
- **Launch at Login** — Optionally start the app automatically when you log in
- **Keyboard Shortcuts** — Quick access with `⌘1` (Tasks), `⌘2` (History), `⌘.` (Stop tracking), and more

## Screenshots

| Tasks View | History View | Timeline View |
|:----------:|:------------:|:-------------:|
| ![Tasks](screenshots/tasks.png) | ![History](screenshots/history.png) | ![Timeline](screenshots/timeline.png) |

> **Note:** Add your own screenshots to the `screenshots/` folder to display them here.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building from source)

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/astrobliss/TimeTracker.git
   cd time-tracker
   ```

2. Open `TimeTracker.xcodeproj` in Xcode

3. Select your development team in **Signing & Capabilities** (or leave unsigned for local use)

4. Build and run (`⌘R`)

The app will appear in your menu bar as a timer icon.

### Pre-built Release

Download the latest release from the [Releases](https://github.com/astrobliss/TimeTracker/releases) page.

## Usage

### Adding Tasks

1. Click the timer icon in the menu bar
2. Click **Add Task** at the bottom
3. Enter a task name, set the time estimate, and optionally select a project
4. Click **Add**

### Tracking Time

1. Find your task in the list
2. Click the play button to start tracking
3. The menu bar will show the remaining time counting down
4. Click the stop button when finished

### Managing Projects

1. Click the folder icon in the bottom-left corner
2. Add, edit, or delete projects
3. Each project has a custom color that appears in task rows and calendar views

### Viewing History

1. Switch to the **History** tab (`⌘2`)
2. Navigate months with the arrow buttons
3. Days with tracked time show colored dots (intensity indicates time tracked)
4. Click a day to see detailed time entries with an hourly timeline

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘1` | Switch to Tasks tab |
| `⌘2` | Switch to History tab |
| `⌘N` | Add new task |
| `⌘.` | Stop current tracking |
| `⌘Q` | Quit application |
| `Esc` | Go back / dismiss |

## Architecture

The app follows a clean MVVM architecture:

- **SwiftUI** — Declarative UI framework for all views
- **SwiftData** — Apple's modern persistence framework for data storage
- **MenuBarExtra** — Native menu bar integration
- **Combine** — Reactive timer updates and state management

### Project Structure

```
TimeTracker/
├── TimeTrackerApp.swift          # App entry point, menu bar setup
├── Models/
│   ├── Project.swift             # Project data model with color support
│   ├── TrackedTask.swift         # Task model with time estimates
│   └── TimeEntry.swift           # Individual time tracking entries
├── Managers/
│   └── TimeTrackingManager.swift # Timer logic and active tracking state
├── Views/
│   ├── ContentView.swift         # Main view with tab navigation
│   ├── Tasks/
│   │   ├── TaskListView.swift    # Task list with filtering
│   │   ├── TaskRowView.swift     # Individual task row component
│   │   ├── AddTaskView.swift     # New task creation form
│   │   ├── SearchFilterBar.swift # Search and filter controls
│   │   └── SettingsMenuView.swift # App settings menu
│   ├── Projects/
│   │   └── ProjectManagerView.swift  # Project CRUD interface
│   ├── History/
│   │   ├── HistoryView.swift     # Calendar-based history view
│   │   ├── DayDetailView.swift   # Daily time entry breakdown
│   │   └── HourlyTimelineView.swift  # Visual hourly timeline
│   └── Stats/
│       └── StatsView.swift       # Statistics and analytics
└── Utilities/
    ├── TimeFormatter.swift       # Time formatting and cached DateFormatters
    ├── LaunchAtLoginManager.swift # SMAppService integration
    └── AppUndoManager.swift      # Undo system with toast notifications
```

## Data Storage

Time Tracker uses SwiftData for persistent storage. Data is stored locally in the app's container at:

```
~/Library/Application Support/TimeTracker/
```

## Contributing

Contributions are welcome! Here's how you can help:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Setup

1. Ensure you have Xcode 15.0+ installed
2. Clone the repo and open `TimeTracker.xcodeproj`
3. The app uses no external dependencies — just build and run

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftUI's declarative patterns
- Keep views small and composable
- Add previews for new views

## Roadmap

- [ ] Export time data to CSV
- [ ] iCloud sync support
- [ ] Weekly/monthly summary reports
- [ ] Custom notification sounds
- [ ] Widget support

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Made with SwiftUI for macOS
</p>

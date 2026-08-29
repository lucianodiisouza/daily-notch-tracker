# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Conventional Commits](https://www.conventionalcommits.org/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [unreleased]

### 🚀 Features

- *(notch)* Corner drag handle and 8pt gap in the to-do row
- *(tasks)* Corner drag handle in the Tasks window row
- *(tasks)* Refined focus time picker (macOS-Clock-style popover)
- *(settings)* Align Alerts with Timer; reuse FocusTimePicker
- *(app)* Show Cmd+Shift+Space in the menu bar

### 🐛 Bug Fixes

- *(notch)* Restore scroll in the to-do list
- *(store)* Done tasks sink to the bottom of every list
- *(store)* Use explicit isBefore comparator for the new sort
- *(store)* Sorted(by:) needs the by: argument label
- *(tasks)* Full hit area on row buttons and title
- *(notch)* OnDragStart() takes no arguments

### 🚜 Refactor

- *(app)* Remove Settings from the menu bar
## [0.0.1] - 2026-08-29

### 🚀 Features

- *(models)* Add Task and FocusSession models
- *(models)* Add Store with JSON persistence and streak logic
- *(focus)* Add Pomodoro FocusTimer engine
- *(design)* Add Theme tokens and rounded-bottom NotchShape
- *(app)* Add NotchMetrics for reading hardware notch geometry
- *(app)* Add NotchViewModel with debounced hover expand/collapse
- *(app)* Add borderless notch panel and window controller
- *(app)* Wire up app entry, menu bar item, and Tasks window controller
- *(notch)* Add root notch view and collapsed timer pill
- *(notch)* Add hover dashboard with to-do panel and streak heatmap
- *(tasks)* Add Tasks window with calendar, day list, and add form
- *(design)* Use macOS system accent color and add inset tray shape
- *(notch)* Graded heatmap shades at prototype dimensions
- *(models)* Seed varied activity history for the graded heatmap
- *(notch)* 2-row scrollable to-do list; tap a row to open the task
- *(activity)* Weekday grid (7 rows), larger cells, drop streak badge
- *(tasks)* Task detail modal for view/edit including focus time
- *(activity)* Scope the graph to the current month
- *(notch)* Show a focus-time pill on each notch to-do row
- *(focus)* Add Carbon-backed GlobalHotkey service for global shortcuts
- *(focus)* Wire global hotkey (Cmd+Shift+Space) to toggle focus
- *(models)* Add sortOrder to Task for drag-to-reorder
- *(tasks)* Drag-to-reorder in the Tasks window
- *(notch)* Drag-to-reorder in the to-do panel
- *(models)* Add FocusSettings (durations + notification toggles)
- *(settings)* Settings sheet for focus + break lengths and alerts
- *(tasks)* Use settings.focusMinutes as the default for new tasks
- *(focus)* Honor settings.focusMinutes in the timer
- *(notifications)* Post a local notification when a focus block ends
- *(sync)* Add CalendarService backed by EventKit
- *(sync)* Add CalendarAuthModel to observe EventKit state in SwiftUI
- *(sync)* Show today's events + auth banner in the Tasks window

### 🐛 Bug Fixes

- *(notch)* Opaque black layer backing to stop wallpaper flash
- *(tasks)* Center Tasks window on the active screen, never under the notch
- *(notch)* Unify progress tray across collapsed and expanded states
- *(scripts)* Make scripts locale-safe (ASCII output, braced vars)
- *(notch)* Closed pill hugs the notch, fixed 2-row expanded height
- *(notch)* Reduce collapsed overhang and make side progress lines read
- *(notch)* Flexible ears so collapsed content fits the window width
- *(notch)* Paint the black pill in SwiftUI instead of a CALayer
- *(notch)* Nest accent tray corners inside the pill
- *(tasks)* Tidy the task detail sheet layout
- *(focus)* Stop the timer when its task is completed or deleted
- *(notch)* Shrink expanded height to the trimmed activity grid
- Window crashing

### 💼 Other

- Add Xcode project (synchronized group, macOS 14 target)
- *(notch)* Notch-safe collapsed pill with left/right ears
- *(notch)* Push dashboard content below the notch line
- *(notch)* Sharpen expanded blue border to match mockups
- *(notch)* Rename to Activity and fit expanded height to content
- *(notch)* Smooth progress tray and visible lateral lines

### 🚜 Refactor

- *(notch)* Render accent tray in root, drop inline progress bar
- *(app)* Observe screen changes via Combine, drop Sendable warning
- *(activity)* Size the grid to weeks needed through today

### 📚 Documentation

- Add README with features, build steps, and architecture
- Document run.sh and wipe.sh scripts

### ⚙️ Miscellaneous Tasks

- Add gitignore and MIT license
- *(scripts)* Add build-and-run and full-uninstall scripts
- *(store)* Drop sample data seeding on first run
- *(assets)* Add AppIcon set (hourglass on black, system accent)
- *(release)* Bump version to 0.0.1
- *(github)* Add build + tag-driven release workflows
- *(github)* Use macos-15 runner for newer Xcode
- *(github)* Fix DMG asset upload — give Create DMG step an id

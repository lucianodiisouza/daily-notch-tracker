# DailyNotch

An open-source macOS **notch app** that turns the space around your MacBook's
notch into a focus + task tracker. Hover the notch to reveal your to-do list and
your activity streak; start a task to run a Pomodoro timer that lives right in
the notch.

> Built with native SwiftUI + AppKit. macOS 14+.

## Features

- **Collapsed pill** — when a focus session is running, the notch shows a live
  countdown, the active task, and a blue progress bar hugging the bottom edge.
- **Hover dashboard** — expands into two panels:
  - **To Do** — today's tasks with one-tap start/pause and quick add.
  - **Journey Streak** — a GitHub-style contribution heatmap of your focus days
    plus a running day streak.
- **Tasks window** — a month calendar, a Day / Unscheduled task list with
  due chips and time estimates, and an inline add-task form (title + notes).
- **Pomodoro engine** — per-task estimates drive the timer; completed blocks are
  recorded and feed the streak.
- **Menu-bar item** — open the Tasks window or quit. No Dock icon (`LSUIElement`).
- **Local-first** — everything persists to JSON in `~/Library/Application Support/DailyNotch/`.

## Build & run

```bash
open DailyNotch.xcodeproj   # then ⌘R in Xcode
```

or from the command line:

```bash
xcodebuild -project DailyNotch.xcodeproj -scheme DailyNotch -configuration Release build
```

The app runs as a menu-bar / notch agent — look for the hourglass in the menu
bar, and hover your notch to open the dashboard.

## Architecture

```
DailyNotch/
├── App/          NSApplication wiring, borderless notch panel, view model, metrics
├── Models/       Task, FocusSession, Store (JSON persistence)
├── Focus/        FocusTimer — the Pomodoro engine
├── Notch/        Collapsed pill + expanded dashboard (to-do + streak heatmap)
├── Tasks/        Standalone Tasks window (calendar + list + add form)
└── Design/       Theme + the rounded-bottom NotchShape
```

Key pieces:

- **`NotchWindowController`** hangs a borderless, non-activating `NSPanel` from the
  top-center of the screen, straddling the hardware notch, and re-anchors it
  (top-center) as the SwiftUI content expands/collapses.
- **`NotchMetrics`** reads the real notch width via `NSScreen.auxiliaryTopLeftArea`
  / `auxiliaryTopRightArea`, falling back to a synthetic pill on non-notched Macs.
- **`Store`** is the single `@MainActor` source of truth, persisted to disk.

## Roadmap

- [ ] Drag-to-reorder tasks
- [ ] Custom Pomodoro / break lengths + notifications
- [ ] Global hotkey to start/stop focus
- [ ] iCloud / calendar sync
- [ ] App icon + notarized release build

## License

MIT — see [LICENSE](LICENSE).

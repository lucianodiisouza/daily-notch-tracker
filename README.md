# DailyNotch

An open-source macOS notch app that turns the space around your MacBook's
notch into a focus + task tracker. Hover the notch to reveal your to-do list
and your activity streak. Start a task to run a focus timer that lives
right in the notch.

Built with native SwiftUI + AppKit. macOS 14+.

## Features

- Collapsed pill - when a focus session is running, the notch shows a live
  countdown, the active task, and a blue progress bar hugging the bottom edge.
- Hover dashboard - expands into two panels:
  - To Do - today's tasks with one-tap start/pause, drag-to-reorder from a
    6-dot corner handle, and quick add.
  - Activity - a GitHub-style heatmap of your focus days plus a running streak.
- Tasks window - month calendar, Day / Unscheduled toggle with drag-to-reorder,
  due chips, time estimates, an inline add form, and a refined focus time
  picker (popover with +/- and preset chips).
- Focus engine - per-task estimates drive the timer. Custom focus and
  break lengths. Completed blocks feed the streak.
- Settings - focus and break durations, notification + sound toggles,
  launch at login. Open from the gear in the Tasks window header.
- Calendar integration - read-only view of today's events from EventKit,
  with a Connect calendar banner on first launch and a deep link to
  System Settings if access is denied.
- Global hotkey - `Cmd+Shift+Space` toggles the active focus session from
  anywhere. The menu bar shows the same shortcut as a visual hint.
- Local notifications - posted when a focus block ends, with the task
  title in the body.
- Launch at login - via `SMAppService.mainApp` (system-managed, no helper
  binary, no extra privileges).
- Menu bar - hourglass icon. Open Tasks, Toggle focus, Quit. No Dock icon
  (`LSUIElement`).
- Local-first - everything persists to JSON in
  `~/Library/Application Support/DailyNotch/`.

## Build & run

```bash
open DailyNotch.xcodeproj   # then Cmd+R in Xcode
```

or from the command line:

```bash
xcodebuild -project DailyNotch.xcodeproj -scheme DailyNotch -configuration Release build
```

The app runs as a menu-bar / notch agent. Look for the hourglass in the menu
bar, then hover your notch to open the dashboard.

### Scripts

```bash
./scripts/run.sh            # build (Debug) and (re)launch
./scripts/run.sh release    # build Release and launch
./scripts/wipe.sh           # completely remove the app, data, and prefs from this Mac
./scripts/wipe.sh -y        # ... without the confirmation prompt
```

`wipe.sh` removes the built app, `~/Library/Application Support/DailyNotch`,
preferences, caches, and any installed copy. It does not touch this repo.

## Installing a release

Releases are published on GitHub:
[github.com/lucianodiisouza/daily-notch-tracker/releases](https://github.com/lucianodiisouza/daily-notch-tracker/releases).
Each release attaches an ad-hoc-signed `DailyNotch-X.Y.Z.dmg`.

### Running an unsigned (ad-hoc signed) build

The DMGs published from CI are ad-hoc signed, not notarized. macOS will
warn on first launch because the developer can't be verified. Two ways
through:

1. **Right-click Open** - in Finder, right-click the app (or the mounted
   DMG) and choose **Open**. Confirm the warning. macOS remembers the
   exception for that app from then on.
2. **Remove the quarantine attribute** - from the terminal:
   ```bash
   xattr -dr com.apple.quarantine /Applications/DailyNotch.app
   ```

If you have an Apple Developer account and want a notarized build instead,
add three secrets to the repo (Settings -> Secrets and variables ->
Actions): `AC_API_KEY_ID`, `AC_API_KEY_ISSUER_ID`, and `AC_API_KEY_P8`
(an App Store Connect API key). The release workflow picks them up
automatically on the next tag.

## Hotkey

`Cmd+Shift+Space` - toggle the active focus session.

If the day has at least one unfinished task, the first one starts. If
the day is empty, a blank session starts using the current `focusMinutes`
setting. Press the shortcut again to stop.

The hotkey is registered via Carbon's `RegisterEventHotKey` (see
`DailyNotch/Focus/GlobalHotkey.swift`), so it works from any app, not
just when DailyNotch is focused.

## Architecture

```
DailyNotch/
+- App/           NSApplication wiring, borderless notch panel, view model, focus menu state
+- Models/        Task, FocusSession, FocusSettings, Store (JSON persistence)
+- Focus/         FocusTimer (focus engine), GlobalHotkey, NotificationService
+- Notch/         Collapsed pill + expanded dashboard (to-do + activity heatmap)
+- Tasks/         Tasks window (calendar + list + add form), TaskRow, FocusTimePicker
+- Settings/      Settings window + view + LaunchAtLoginController
+- Sync/          CalendarService (EventKit, read-only) + CalendarAuthModel
+- Design/        Theme tokens + rounded-bottom NotchShape
+- Assets.xcassets/   App icon (hourglass on black, system accent)
```

Key pieces:

- `NotchWindowController` hangs a borderless, non-activating `NSPanel` from
  the top-center of the screen, straddling the hardware notch, and
  re-anchors it (top-center) as the SwiftUI content expands/collapses.
- `NotchMetrics` reads the real notch width via
  `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea`, falling back
  to a synthetic pill on non-notched Macs.
- `Store` is the single `@MainActor` source of truth, persisted to disk.
  Tasks sort with undone before done, then by user-controlled `sortOrder`,
  then by `createdAt` as a stable tiebreaker.
- `NotificationService` wraps `UNUserNotificationCenter` and posts a single
  'focus block complete' notification with the task title in the body.

## Contributing

Issues and pull requests are welcome. A few conventions to keep the project
consistent:

- **Commits** follow [Conventional Commits](https://www.conventionalcommits.org/):
  `feat(scope): ...`, `fix(scope): ...`, `refactor(scope): ...`,
  `chore(scope): ...`, `polish(scope): ...`, `docs(scope): ...`, `ci(scope): ...`.
  Scope is the folder or layer (`focus`, `notch`, `tasks`, `store`, `app`,
  `ci`, etc). One logical change per commit.
- **No em-dashes or en-dashes in code, comments, commit messages, or docs.**
  Use ` - ` (hyphen with surrounding spaces) for parenthetical asides.
  The same rule applies to user-facing strings shown in the app.
- **CHANGELOG is auto-generated** from your commit messages by `git-cliff`
  in the release pipeline. You do not need to touch `CHANGELOG.md` in your
  PR. A new section appears under your commit type on the next tag.
- **Before opening a PR**, run a clean Debug build locally and exercise
  the area you touched. The release workflow runs on every push to `main`
  and a green check on your branch is the easiest way to know it's good.
- **App icon** is committed under `DailyNotch/Assets.xcassets/AppIcon.appiconset/`.
  Don't regenerate the slots yourself - if you change the master, re-run
  `sips` to refresh the derived sizes.

### Project file format

The `.xcodeproj` uses Xcode 16.3's `PBXFileSystemSynchronizedRootGroup`,
which means the `DailyNotch/` folder is auto-synced. You should rarely
need to edit `project.pbxproj` directly - new files dropped into the
folder are picked up automatically.

## License

MIT - see [LICENSE](LICENSE).

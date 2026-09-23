import SwiftUI
import AppKit
import Carbon.HIToolbox
import Combine

@main
struct DailyNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var focusMenu = FocusMenuState.shared
    @ObservedObject private var updateChecker = UpdateChecker.shared

    var body: some Scene {
        MenuBarExtra {
            Button("Open Tasks…") { appDelegate.showTasksWindow() }
                .keyboardShortcut("t")
            Button(focusMenu.isFocusing ? "Stop focus" : "Start focus") {
                appDelegate.focus.toggleStartStop()
            }
            .keyboardShortcut(.space, modifiers: [.command, .shift])
            Divider()
            Button("Settings…") { appDelegate.showSettingsWindow() }
                .keyboardShortcut(",")
            if let update = updateChecker.availableUpdate {
                Button("Update to \(update.version) available…") {
                    updateChecker.openReleasePage()
                }
            } else {
                Button("Version \(updateChecker.currentVersion)") {}
                    .disabled(true)
            }
            Divider()
            Button("Quit DailyNotch") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            // Bare hourglass (no enclosing circle), sized up a touch so it
            // matches the visual weight of the neighbouring menu-bar icons.
            Image(systemName: "hourglass")
                .font(.system(size: 16, weight: .regular))
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The running delegate. `NSApp.delegate` is SwiftUI's adaptor, not this
    /// class, so views that need to open a window reach it through here.
    private(set) static weak var shared: AppDelegate?

    let store = Store()
    lazy var focus = FocusTimer(store: store)
    private var notchController: NotchWindowController?
    private var tasksController: TasksWindowController?
    private var settingsController: SettingsWindowController?
    private var viewModel: NotchViewModel?
    private let hotkey = GlobalHotkey()
    private var focusCancellable: AnyCancellable?
    /// Mirrors `store.settings.displayPreference` into the view model so the
    /// notch window controller can react via `viewModel.$displayPreference`.
    private var displayPreferenceCancellable: AnyCancellable?
    private var hotkeyCancellable: AnyCancellable?

    /// Number of user-openable windows currently up. Drives the activation
    /// policy: the app stays `.accessory` (menu-bar only) until the user
    /// opens Tasks or Settings, at which point it becomes `.regular` so the
    /// window gets a Dock icon and joins the Alt-Tab list.
    private var userWindowCount = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        #if DEBUG
        if Snapshots.isRequested { Snapshots.run() }
        #endif
        NSApp.setActivationPolicy(.accessory)   // no Dock icon; lives in the notch

        // Completing or deleting a task must stop its running session so the
        // collapsed pill's progress line resets instead of running on.
        store.onTaskDeactivated = { [weak self] id, record in
            self?.focus.stopIfActive(id, record: record)
        }
        store.onTaskUpdated = { [weak self] task in
            self?.focus.taskDidChange(task)
        }

        // If the user has notifications on, request authorization on launch so
        // the system prompt is out of the way before the first focus block.
        if store.settings.notificationsEnabled {
            NotificationService.shared.requestAuthorizationIfNeeded()
        }

        // Mirror focus state into the menu so the menu label can show
        // "Start focus" / "Stop focus" live.
        focusCancellable = focus.$state
            .map { $0 != .idle }
            .removeDuplicates()
            .sink { FocusMenuState.shared.update(isFocusing: $0) }

        // Cmd+Shift+Space: toggle the active focus session from anywhere,
        // unless the user switched it off in Settings.
        hotkeyCancellable = store.$settings
            .map(\.globalHotkeyEnabled)
            .removeDuplicates()
            .sink { [weak self] enabled in self?.applyHotkey(enabled) }

        // Check GitHub for a newer release so the menu can offer an update.
        UpdateChecker.shared.checkForUpdates()

        let vm = NotchViewModel(store: store, focus: focus, metrics: .primary)
        // Hydrate from the persisted preference before the controller subscribes
        // to `$displayPreference` so the first `reposition(animated: false)`
        // already uses the correct screen. Without this, the saved value would
        // arrive later via the mirror sink and trigger a redundant dock.
        vm.displayPreference = store.settings.displayPreference
        vm.openTasksWindow = { [weak self] in self?.showTasksWindow() }
        viewModel = vm
        displayPreferenceCancellable = store.$settings
            .map(\.displayPreference)
            .removeDuplicates()
            .sink { [weak vm] preference in
                vm?.displayPreference = preference
            }
        notchController = NotchWindowController(viewModel: vm)
    }

    func showTasksWindow() {
        if tasksController == nil {
            let c = TasksWindowController(store: store, focus: focus)
            // Drop the controller on close so the next open counts as a new
            // window again; keeping it left the count at zero and the reopened
            // window without a Dock icon or a place in ⌘Tab.
            c.onClose = { [weak self] in
                self?.tasksController = nil
                self?.userWindowDidClose()
            }
            tasksController = c
            bumpUserWindowCount()
        }
        tasksController?.show()
    }

    func showSettingsWindow(_ page: SettingsPageID? = nil) {
        if settingsController == nil {
            let c = SettingsWindowController(store: store)
            c.onClose = { [weak self] in
                self?.settingsController = nil
                self?.userWindowDidClose()
            }
            settingsController = c
            bumpUserWindowCount()
        }
        settingsController?.show(page)
    }

    private func applyHotkey(_ enabled: Bool) {
        if enabled {
            let ok = hotkey.register(
                keyCode: UInt32(kVK_Space),
                modifiers: UInt32(cmdKey | shiftKey)
            ) { [weak self] in
                self?.focus.toggleStartStop()
            }
            FocusMenuState.shared.hotkeyRegistered = ok
        } else {
            hotkey.unregister()
            FocusMenuState.shared.hotkeyRegistered = false
        }
    }

    private func bumpUserWindowCount() {
        userWindowCount += 1
        if userWindowCount == 1 {
            // First user window — promote to a regular app so the Dock icon
            // appears and the window joins the Alt-Tab cycle.
            NSApp.setActivationPolicy(.regular)
        }
    }

    private func userWindowDidClose() {
        userWindowCount = max(0, userWindowCount - 1)
        if userWindowCount == 0 {
            // All user windows closed — revert to menu-bar-only mode.
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

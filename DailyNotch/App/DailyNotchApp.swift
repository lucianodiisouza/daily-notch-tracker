import SwiftUI
import AppKit
import Carbon.HIToolbox
import Combine

@main
struct DailyNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var focusMenu = FocusMenuState.shared

    var body: some Scene {
        MenuBarExtra("DailyNotch", systemImage: "hourglass.circle") {
            Button("Open Tasks…") { appDelegate.showTasksWindow() }
                .keyboardShortcut("t")
            Button(focusMenu.isFocusing ? "Stop focus" : "Start focus") {
                appDelegate.focus.toggleStartStop()
            }
            .keyboardShortcut(.space, modifiers: [.command, .shift])
            Divider()
            Button("Quit DailyNotch") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = Store()
    lazy var focus = FocusTimer(store: store)
    private var notchController: NotchWindowController?
    private var tasksController: TasksWindowController?
    private var settingsController: SettingsWindowController?
    private var viewModel: NotchViewModel?
    private let hotkey = GlobalHotkey()
    private var focusCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // no Dock icon; lives in the notch

        // Completing or deleting a task must stop its running session so the
        // collapsed pill's progress line resets instead of running on.
        store.onTaskDeactivated = { [weak self] id, record in
            self?.focus.stopIfActive(id, record: record)
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

        // Cmd+Shift+Space: toggle the active focus session from anywhere.
        hotkey.register(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(cmdKey | shiftKey)
        ) { [weak self] in
            self?.focus.toggleStartStop()
        }

        let vm = NotchViewModel(store: store, focus: focus, metrics: .primary)
        vm.openTasksWindow = { [weak self] in self?.showTasksWindow() }
        viewModel = vm
        notchController = NotchWindowController(viewModel: vm)
    }

    func showTasksWindow() {
        if tasksController == nil {
            tasksController = TasksWindowController(store: store, focus: focus)
        }
        tasksController?.show()
    }

    func showSettingsWindow() {
        if settingsController == nil {
            settingsController = SettingsWindowController(store: store)
        }
        settingsController?.show()
    }
}

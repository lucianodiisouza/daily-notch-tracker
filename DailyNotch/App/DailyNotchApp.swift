import SwiftUI
import AppKit
import Carbon.HIToolbox

@main
struct DailyNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("DailyNotch", systemImage: "hourglass.circle") {
            Button("Open Tasks…") { appDelegate.showTasksWindow() }
                .keyboardShortcut("t")
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
    private var viewModel: NotchViewModel?
    private let hotkey = GlobalHotkey()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // no Dock icon; lives in the notch

        // Completing or deleting a task must stop its running session so the
        // collapsed pill's progress line resets instead of running on.
        store.onTaskDeactivated = { [weak self] id, record in
            self?.focus.stopIfActive(id, record: record)
        }

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
}

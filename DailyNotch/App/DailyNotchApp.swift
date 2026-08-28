import SwiftUI
import AppKit

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // no Dock icon; lives in the notch

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

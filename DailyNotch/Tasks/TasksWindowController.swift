import AppKit
import SwiftUI

/// Owns the standalone "Tasks" window (calendar + day list + add form).
@MainActor
final class TasksWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let store: Store
    private let focus: FocusTimer

    init(store: Store, focus: FocusTimer) {
        self.store = store
        self.focus = focus
    }

    func show() {
        if window == nil {
            let root = TasksWindowView()
                .environmentObject(store)
                .environmentObject(focus)

            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 480),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false)
            win.title = "Tasks"
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.isMovableByWindowBackground = true
            win.backgroundColor = NSColor.black
            win.contentView = NSHostingView(rootView: root)
            win.delegate = self
            win.center()
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

import AppKit
import SwiftUI

/// Owns the standalone "Settings" window. Same pattern as
/// `TasksWindowController`: ARC owns the window, AppKit's extra release on
/// close is disabled, and we drop the reference when the window closes.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let store: Store

    /// Fires when the window is about to close. The app delegate uses this to
    /// drop the activation policy back to `.accessory` when the last user-
    /// openable window goes away.
    var onClose: (() -> Void)?

    init(store: Store) {
        self.store = store
    }

    func show() {
        if window == nil {
            let root = SettingsView().environmentObject(store)
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false)
            win.isReleasedWhenClosed = false
            win.title = "Settings"
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.isMovableByWindowBackground = true
            win.backgroundColor = NSColor.black
            win.contentView = NSHostingView(rootView: root)
            win.delegate = self
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        onClose?()
    }
}

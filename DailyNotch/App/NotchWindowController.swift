import AppKit
import SwiftUI
import Combine

/// Borderless, non-activating panel that hangs from the top-center of the
/// screen, straddling the hardware notch. Resizes (anchored top-center) as the
/// SwiftUI content expands and collapses.
final class NotchWindowController {
    private let panel: NotchPanel
    private let viewModel: NotchViewModel
    private var cancellables = Set<AnyCancellable>()
    private var screenObserver: NSObjectProtocol?

    @MainActor
    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel

        let content = RootNotchView()
            .environmentObject(viewModel)
            .environmentObject(viewModel.store)
            .environmentObject(viewModel.focus)

        panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 40))

        // Opaque black backing with rounded BOTTOM corners. Because it's a real
        // CALayer it resizes in lockstep with the window, so animating the frame
        // never exposes a transparent gap (which showed the wallpaper).
        let backing = NSView()
        backing.wantsLayer = true
        backing.layer?.backgroundColor = NSColor.black.cgColor
        backing.layer?.cornerRadius = Theme.notchCorner
        backing.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        backing.layer?.masksToBounds = true

        let hosting = NSHostingView(rootView: content)
        hosting.frame = backing.bounds
        hosting.autoresizingMask = [.width, .height]
        backing.addSubview(hosting)
        panel.contentView = backing

        // Re-anchor whenever the target size changes.
        viewModel.$expanded
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reposition(animated: true) }
            .store(in: &cancellables)
        viewModel.focus.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reposition(animated: true) }
            .store(in: &cancellables)

        // Re-dock when displays change (monitor plugged in, resolution change…).
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reposition(animated: false) }
            }

        reposition(animated: false)
        panel.orderFrontRegardless()
    }

    deinit {
        screenObserver.map { NotificationCenter.default.removeObserver($0) }
    }

    @MainActor
    private func reposition(animated: Bool) {
        let screen = viewModel.metrics.screen
        let size = viewModel.targetSize
        let x = screen.frame.midX - size.width / 2
        let y = screen.frame.maxY - size.height   // top edge flush with screen top
        let frame = NSRect(x: x, y: y, width: size.width, height: size.height)

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.24
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            } completionHandler: { [weak panel] in
                panel?.orderFrontRegardless()
            }
        } else {
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
        }
    }
}

/// Panel that never activates the app but still lets SwiftUI controls receive clicks.
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        // Sit above the menu-bar / status strip so we can overlap the notch.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// By default Cocoa keeps windows below the menu bar; we need to sit *in*
    /// that strip (straddling the notch), so don't let it re-constrain us.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

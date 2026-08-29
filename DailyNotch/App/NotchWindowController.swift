import AppKit
import SwiftUI
import Combine

/// Borderless, non-activating panel that hangs from the top-center of the
/// screen, straddling the hardware notch. Resizes (anchored top-center) as the
/// SwiftUI content expands and collapses.
final class NotchWindowController {
    private let panel: NotchPanel
    private let hosting: NSHostingView<AnyView>
    private let viewModel: NotchViewModel
    private var cancellables = Set<AnyCancellable>()

    @MainActor
    init(viewModel: NotchViewModel, pomodoro: PomodoroEngine) {
        self.viewModel = viewModel

        let content = AnyView(
            RootNotchView()
                .environmentObject(viewModel)
                .environmentObject(viewModel.store)
                .environmentObject(viewModel.focus)
                .environmentObject(pomodoro)
        )

        panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 40))

        // The black pill + rounded corners are painted in SwiftUI (RootNotchView).
        // NSHostingView manages its own layer's background, so painting via CALayer
        // here renders translucent and clips content — SwiftUI is the reliable path.
        hosting = NSHostingView(rootView: content)
        panel.contentView = hosting

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
        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reposition(animated: false) }
            .store(in: &cancellables)

        reposition(animated: false)
        panel.orderFrontRegardless()
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

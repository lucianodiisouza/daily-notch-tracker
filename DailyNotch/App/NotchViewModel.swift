import SwiftUI
import Combine

/// Drives the notch panel's collapsed ⇄ expanded state and hands the window
/// controller a target size to animate to.
@MainActor
final class NotchViewModel: ObservableObject {
    @Published var expanded = false

    let store: Store
    let focus: FocusTimer
    let metrics: NotchMetrics

    /// Set by the app so the "expand" arrow / "Add a task" can open the big window.
    var openTasksWindow: () -> Void = {}

    init(store: Store, focus: FocusTimer, metrics: NotchMetrics) {
        self.store = store
        self.focus = focus
        self.metrics = metrics
    }

    // MARK: Layout targets (points)

    /// Real hardware notch footprint — content must never sit inside this.
    var notchWidth: CGFloat { metrics.notchWidth }
    var notchHeight: CGFloat { metrics.notchHeight }

    /// Width of each "ear" flanking the notch in the collapsed active pill.
    let activeEarWidth: CGFloat = 158

    /// Extra width added on EACH side in minimal mode so the tray's vertical
    /// side segments clear the physical notch edges and stay visible (a pill of
    /// exactly `notchWidth` hides them behind the camera housing).
    let minimalSideMargin: CGFloat = 26

    var collapsedHeight: CGFloat {
        // Keep the dark overhang below the notch small; just enough room for the
        // progress tray to show its bottom + short side segments. With the
        // timeline disabled there's no tray to make room for, so the pill sits
        // flush at the exact hardware-notch height. Minimal mode trims the
        // overhang further so the line hugs the notch's bottom edge.
        guard focus.isActive && store.settings.showTimeline else { return notchHeight }
        return store.settings.minimalMode ? notchHeight + 8 : notchHeight + 14
    }

    /// Fixed height: always exactly two visible to-do rows (the list scrolls if
    /// there are more) alongside the weekday activity grid.
    static let todoRowHeight: CGFloat = 52
    static let visibleTodoRows = 2

    var expandedHeight: CGFloat {
        let rows = CGFloat(Self.visibleTodoRows)
        let todoColumn = 22 + rows * Self.todoRowHeight + (rows - 1) * 6 + 30
        // header + only the week-rows the current month needs through today.
        let heatmapColumn = 22 + StreakHeatmap.gridHeight(rows: StreakHeatmap.weekRows(for: Date()))
        return notchHeight + 4 + max(todoColumn, heatmapColumn) + 14
    }

    var collapsedWidth: CGFloat {
        // Idle: hug the notch exactly (invisible). Active normal: notch + two
        // ears. Active minimal: notch + a small side margin so the tray's side
        // segments clear the notch edges.
        guard focus.isActive else { return notchWidth }
        return store.settings.minimalMode
            ? notchWidth + minimalSideMargin * 2
            : notchWidth + activeEarWidth * 2
    }
    var expandedWidth: CGFloat { 620 }

    var targetSize: CGSize {
        expanded
            ? CGSize(width: expandedWidth, height: expandedHeight)
            : CGSize(width: collapsedWidth, height: collapsedHeight)
    }

    // MARK: Hover handling

    /// Delay before collapsing on mouse-exit. Prevents the expand⇄collapse
    /// flicker that happens when the window resizes out from under the cursor.
    private var collapseTask: DispatchWorkItem?

    /// Number of open child windows (popovers, menus) that should keep the
    /// panel expanded. A `.popover` presents in its own window, so moving the
    /// cursor into it fires `.onHover(false)` on the panel — without this the
    /// notch would collapse out from under the popover. Set by `begin/endHold`.
    private var holdCount = 0

    /// Whether the pointer is currently within the panel frame. Wired by the
    /// window controller so we can re-evaluate collapse when a hold ends
    /// (the popover window swallowed the panel's hover events while open).
    var isPointerInside: () -> Bool = { false }

    /// Called from the SwiftUI `.onHover`. Expands immediately, collapses lazily.
    func hover(_ inside: Bool) {
        collapseTask?.cancel()
        collapseTask = nil

        if inside {
            guard !expanded else { return }
            withAnimation(.easeInEaseOut(duration: 0.24)) { expanded = true }
        } else {
            scheduleCollapse()
        }
    }

    /// Keep the panel expanded while a popover/menu is open. Balanced by `endHold`.
    func beginHold() {
        holdCount += 1
        collapseTask?.cancel()
        collapseTask = nil
    }

    /// Release a hold. If nothing else holds the panel open and the pointer has
    /// left the panel, collapse lazily — mirroring a normal mouse-exit.
    func endHold() {
        holdCount = max(0, holdCount - 1)
        guard holdCount == 0, !isPointerInside() else { return }
        scheduleCollapse()
    }

    private func scheduleCollapse() {
        guard holdCount == 0 else { return }   // held open by a popover/menu
        collapseTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self, self.expanded, self.holdCount == 0,
                  !self.isPointerInside() else { return }
            withAnimation(.easeInEaseOut(duration: 0.24)) { self.expanded = false }
        }
        collapseTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
    }
}

private extension Animation {
    static func easeInEaseOut(duration: Double) -> Animation { .easeInOut(duration: duration) }
}

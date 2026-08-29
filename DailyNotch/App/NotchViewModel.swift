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

    var collapsedHeight: CGFloat {
        focus.isActive ? notchHeight + 16 : notchHeight + 4
    }

    /// Fit the expanded panel to its content (the taller of the two columns)
    /// so there's no dead space below. Caps the to-do list at 3 visible rows.
    var expandedHeight: CGFloat {
        let taskCount = min(3, max(store.tasks(on: Date()).count, 1))
        let rowH: CGFloat = 52
        let todoColumn = 22 + CGFloat(taskCount) * rowH
            + CGFloat(max(0, taskCount - 1)) * 6 + 30   // header + rows + "Add a task"
        let heatmapColumn: CGFloat = 22 + 74            // header + 4-row grid
        return notchHeight + 4 + max(todoColumn, heatmapColumn) + 14
    }

    var collapsedWidth: CGFloat {
        // Idle: hug the notch exactly (invisible). Active: notch + two ears.
        focus.isActive ? notchWidth + activeEarWidth * 2 : notchWidth
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

    /// Called from the SwiftUI `.onHover`. Expands immediately, collapses lazily.
    func hover(_ inside: Bool) {
        collapseTask?.cancel()
        collapseTask = nil

        if inside {
            guard !expanded else { return }
            withAnimation(.easeInEaseOut(duration: 0.24)) { expanded = true }
        } else {
            let task = DispatchWorkItem { [weak self] in
                guard let self, self.expanded else { return }
                withAnimation(.easeInEaseOut(duration: 0.24)) { self.expanded = false }
            }
            collapseTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
        }
    }
}

private extension Animation {
    static func easeInEaseOut(duration: Double) -> Animation { .easeInOut(duration: duration) }
}

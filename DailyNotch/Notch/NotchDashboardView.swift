import SwiftUI

/// Expanded hover panel: To-Do list on the left, streak heatmap on the right.
struct NotchDashboardView: View {
    @EnvironmentObject private var vm: NotchViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            TodoPanel()
                .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 1)
            StreakHeatmap()
                .frame(width: 204, alignment: .topLeading)
        }
        .padding(.horizontal, 18)
        // Clear the physical notch: content starts below the notch height.
        .padding(.top, vm.notchHeight + 4)
        .padding(.bottom, 14)
    }
}

/// Left panel — task list with per-row start/stop + "Add a task".
struct TodoPanel: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var focus: FocusTimer

    @State private var draggingFrom: Int?
    @State private var dragOffset: CGFloat = 0

    private let rowHeight = NotchViewModel.todoRowHeight
    private let rowGap: CGFloat = 8

    /// Completed tasks drop out of the notch stack — only what's left to do.
    private var todays: [Task] { store.tasks(on: Date()).filter { !$0.isDone } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("To Do", systemImage: "checklist")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button { vm.openTasksWindow() } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // Exactly two rows tall; scrolls when there are more tasks.
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: rowGap) {
                    ForEach(Array(todays.enumerated()), id: \.element.id) { index, task in
                        TodoRow(
                            task: task,
                            index: index,
                            isDragging: draggingFrom == index,
                            onDragStart: { handleDragStart(index) },
                            onDragChanged: { handleDragChanged($0) },
                            onDragEnd: handleDragEnd
                        )
                        .offset(y: offsetForIndex(index))
                        .zIndex(draggingFrom == index ? 1 : 0)
                        .animation(.easeOut(duration: 0.18), value: targetIndex())
                    }
                }
            }
            .frame(height: CGFloat(NotchViewModel.visibleTodoRows) * rowHeight
                   + CGFloat(NotchViewModel.visibleTodoRows - 1) * rowGap)

            Button { vm.openTasksWindow() } label: {
                Text("Add a task")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Custom drag bookkeeping

    private func handleDragStart(_ index: Int) {
        draggingFrom = index
        dragOffset = 0
    }

    private func handleDragChanged(_ offset: CGFloat) {
        dragOffset = offset
    }

    private func handleDragEnd() {
        if let from = draggingFrom {
            let to = targetIndex()
            if to != from {
                store.moveTasks(in: todays, from: IndexSet(integer: from), to: to)
            }
        }
        draggingFrom = nil
        dragOffset = 0
    }

    /// Where the dragged row would land if released right now.
    private func targetIndex() -> Int {
        guard let from = draggingFrom else { return 0 }
        let total = todays.count
        guard total > 0 else { return 0 }
        let stride = rowHeight + rowGap
        let rowsMoved = Int((dragOffset / stride).rounded())
        return max(0, min(total - 1, from + rowsMoved))
    }

    /// Per-row vertical offset: dragged row tracks the cursor, the rows
    /// between `from` and `target` shift one stride to make space.
    private func offsetForIndex(_ index: Int) -> CGFloat {
        guard let from = draggingFrom else { return 0 }
        if index == from { return dragOffset }
        let target = targetIndex()
        let stride = rowHeight + rowGap
        if target > from, index > from, index <= target { return -stride }
        if target < from, index < from, index >= target { return stride }
        return 0
    }
}

private struct TodoRow: View {
    let task: Task
    let index: Int
    let isDragging: Bool
    let onDragStart: () -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnd: () -> Void

    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var focus: FocusTimer

    private var isRunningThis: Bool {
        focus.isActive && focus.activeTask?.id == task.id
    }

    var body: some View {
        HStack(spacing: 10) {
            Button { store.toggleDone(task) } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(task.isDone ? Theme.accent : Theme.textSecondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                store.pendingOpenTaskID = task.id
                vm.openTasksWindow()
            }
            Spacer(minLength: 6)

            // Estimate pill — lets you eyeball the quick vs. heavy tasks at a glance.
            HStack(spacing: 3) {
                Image(systemName: "clock").font(.system(size: 9))
                Text(task.estimateLabel).font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color.white.opacity(0.06), in: Capsule())

            Button {
                if isRunningThis { focus.togglePause() } else { focus.start(task: task) }
            } label: {
                Image(systemName: isRunningThis && focus.state == .running ? "pause.fill" : "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
                    .background(isRunningThis && focus.state == .running ? Theme.danger : Theme.accent,
                                in: Circle())
            }
            .buttonStyle(.plain)

            // Drag handle — six dots in a 2×3 grid. Only this corner is
            // draggable; the rest of the row keeps its tap-to-open behavior.
            DragHandle()
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            if !isDragging { onDragStart() }
                            onDragChanged(value.translation.height)
                        }
                        .onEnded { _ in onDragEnd() }
                )
        }
        .padding(.horizontal, 8)
        .frame(height: NotchViewModel.todoRowHeight)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.panelCorner))
    }
}

/// Six dots in a 2×3 grid. Compact so it fits the notch row.
private struct DragHandle: View {
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) { dot; dot }
            HStack(spacing: 2) { dot; dot }
            HStack(spacing: 2) { dot; dot }
        }
        .frame(width: 12, height: 12)
        .contentShape(Rectangle())
    }

    private var dot: some View {
        Circle()
            .fill(Theme.textSecondary.opacity(0.65))
            .frame(width: 2.5, height: 2.5)
    }
}

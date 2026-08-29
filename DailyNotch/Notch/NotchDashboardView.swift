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

    // Completed tasks drop out of the notch stack — only what's left to do.
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
            List {
                ForEach(todays) { task in
                    TodoRow(task: task)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                .onMove { source, destination in
                    store.moveTasks(in: todays, from: source, to: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(height: CGFloat(NotchViewModel.visibleTodoRows) * NotchViewModel.todoRowHeight
                   + CGFloat(NotchViewModel.visibleTodoRows - 1) * 6)

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
}

private struct TodoRow: View {
    let task: Task
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
                    .background(isRunningThis && focus.state == .running ? Theme.danger : Theme.accent,
                                in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(height: NotchViewModel.todoRowHeight)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.panelCorner))
        // Tap anywhere else on the row to open the task's detail.
        .contentShape(RoundedRectangle(cornerRadius: Theme.panelCorner))
        .onTapGesture {
            store.pendingOpenTaskID = task.id
            vm.openTasksWindow()
        }
    }
}

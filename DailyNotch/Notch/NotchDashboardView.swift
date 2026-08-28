import SwiftUI

/// Expanded hover panel: To-Do list on the left, streak heatmap on the right.
struct NotchDashboardView: View {
    @EnvironmentObject private var vm: NotchViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            TodoPanel()
                .frame(maxWidth: .infinity, alignment: .leading)
            StreakHeatmap()
                .frame(width: 250, alignment: .topLeading)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }
}

/// Left panel — task list with per-row start/stop + "Add a task".
struct TodoPanel: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var focus: FocusTimer

    private var todays: [Task] { store.tasks(on: Date()) }

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

            VStack(spacing: 6) {
                ForEach(todays.prefix(3)) { task in
                    TodoRow(task: task)
                }
            }

            Button { vm.openTasksWindow() } label: {
                Text("Add a task")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct TodoRow: View {
    let task: Task
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
        .padding(8)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.panelCorner))
    }
}

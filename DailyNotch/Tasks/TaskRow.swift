import SwiftUI

/// A row in the Tasks window: checkbox, title, due chip, estimate, and
/// start / edit / delete controls.
struct TaskRow: View {
    let task: Task
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var focus: FocusTimer
    @State private var editing = false
    @State private var editTitle = ""

    private var isRunningThis: Bool { focus.isActive && focus.activeTask?.id == task.id }

    var body: some View {
        HStack(spacing: 10) {
            Button { store.toggleDone(task) } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(task.isDone ? Theme.accent : Theme.textSecondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                if editing {
                    TextField("Title", text: $editTitle, onCommit: commitEdit)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                } else {
                    Text(task.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .strikethrough(task.isDone)
                        .lineLimit(1)
                }
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let date = task.scheduledDate {
                chip(icon: "calendar", text: Calendar.current.isDateInToday(date)
                     ? "Today" : date.formatted(.dateTime.month().day()))
            }
            chip(icon: "clock", text: task.estimateLabel)

            iconButton(isRunningThis && focus.state == .running ? "pause.fill" : "play.fill",
                       bg: isRunningThis && focus.state == .running ? Theme.danger : Theme.accent) {
                if isRunningThis { focus.togglePause() } else { focus.start(task: task) }
            }
            iconButton("pencil", bg: .clear, fg: Theme.textSecondary) { beginEdit() }
            iconButton("trash", bg: .clear, fg: Theme.textSecondary) { store.delete(task) }
        }
        .padding(10)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
    }

    private func chip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9))
            Text(text).font(.system(size: 11))
        }
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.white.opacity(0.06), in: Capsule())
    }

    private func iconButton(_ icon: String, bg: Color, fg: Color = .white,
                            _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(fg)
                .frame(width: 26, height: 26)
                .background(bg, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func beginEdit() {
        editTitle = task.title
        editing = true
    }

    private func commitEdit() {
        var updated = task
        updated.title = editTitle
        store.update(updated)
        editing = false
    }
}

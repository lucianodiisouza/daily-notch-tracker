import SwiftUI

/// A row in the Tasks window: checkbox, title, due chip, estimate, and
/// start / delete controls. Tapping the row opens the task's detail sheet.
/// Drag handle in the corner is the only draggable area.
struct TaskRow: View {
    let task: Task
    let index: Int
    let isDragging: Bool
    let onDragStart: () -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnd: () -> Void
    var onOpen: () -> Void = {}

    @EnvironmentObject private var store: Store
    @EnvironmentObject private var focus: FocusTimer

    private var isRunningThis: Bool { focus.isActive && focus.activeTask?.id == task.id }

    var body: some View {
        HStack(spacing: 10) {
            Button { store.toggleDone(task) } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(task.isDone ? Theme.accent : Theme.textSecondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .strikethrough(task.isDone)
                    .lineLimit(1)
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onOpen() }

            Spacer(minLength: 8)

            if let date = task.scheduledDate {
                chip(icon: "calendar", text: Calendar.current.isDateInToday(date)
                     ? "Today" : date.formatted(.dateTime.month().day()))
            }
            // Inline time editor — tapping opens the popover, changes persist
            // back to the store immediately. Six presets keep the popover
            // from clipping the last chip.
            FocusTimePicker(
                minutes: estimateBinding,
                range: FocusSettings.focusRange,
                presets: [10, 15, 25, 30, 45, 60]
            )

            iconButton(isRunningThis && focus.state == .running ? "pause.fill" : "play.fill",
                       bg: isRunningThis && focus.state == .running ? Theme.danger : Theme.accent) {
                if isRunningThis { focus.togglePause() } else { focus.start(task: task) }
            }
            iconButton("trash", bg: .clear, fg: Theme.textSecondary) { store.delete(task) }

            // Drag handle — six dots in a 2×3 grid. Only this corner drags;
            // minimumDistance: 3 keeps a stray click from flashing the row.
            DragHandle()
                .gesture(
                    DragGesture(minimumDistance: 3, coordinateSpace: .local)
                        .onChanged { value in
                            if !isDragging { onDragStart() }
                            onDragChanged(value.translation.height)
                        }
                        .onEnded { _ in onDragEnd() }
                )
        }
        .padding(10)
        .background(isDragging ? Theme.panelHover : Theme.panel,
                    in: RoundedRectangle(cornerRadius: 12))
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isDragging)
    }

    /// Two-way binding that writes the new estimate back to the store as soon
    /// as the picker mutates it (the popover's +/- and preset chips both bind
    /// through this).
    private var estimateBinding: Binding<Int> {
        Binding(
            get: { task.estimateMinutes },
            set: { newValue in
                var updated = task
                updated.estimateMinutes = newValue
                store.update(updated)
            }
        )
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
                .contentShape(Rectangle())   // hit area = full 26×26, not just the circle
                .background(bg, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Six dots in a 2×3 grid. Used as the drag handle in both the notch and
/// the Tasks window. Hover state lifts opacity and adds a soft background
/// so users can tell it's grabbable before they commit to a drag.
struct DragHandle: View {
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) { dot; dot }
            HStack(spacing: 3) { dot; dot }
            HStack(spacing: 3) { dot; dot }
        }
        .frame(width: 22, height: 22)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(isHovered ? 0.10 : 0.04))
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .help("Drag to reorder")
    }

    private var dot: some View {
        Circle()
            .fill(Theme.textSecondary.opacity(isHovered ? 0.9 : 0.55))
            .frame(width: 3.5, height: 3.5)
    }
}

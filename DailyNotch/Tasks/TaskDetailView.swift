import SwiftUI

/// Modal sheet to view/edit a single task: title, notes, focus time, date,
/// completion — plus start / delete actions.
struct TaskDetailView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var focus: FocusTimer
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Task

    init(task: Task) { _draft = State(initialValue: task) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Task")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            field("Title") {
                TextField("Task title", text: $draft.title)
                    .textFieldStyle(.plain)
            }

            field("Notes") {
                TextField("Notes (optional)", text: $draft.notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...5)
            }

            HStack(alignment: .top, spacing: 12) {
                // Focus-time editor: refined popover picker (clock icon +
                // current value, tap to open a macOS-Clock-style popover
                // with +/- and preset chips).
                field("Focus time") {
                    FocusTimePicker(
                        minutes: $draft.estimateMinutes,
                        range: FocusSettings.focusRange,
                        presets: [15, 25, 30, 45, 60, 90]
                    )
                }
                field("Date") {
                    DatePicker("", selection: Binding(
                        get: { draft.scheduledDate ?? Date() },
                        set: { draft.scheduledDate = $0 }),
                        displayedComponents: .date)
                    .datePickerStyle(.field)
                    .labelsHidden()
                }
            }

            Toggle(isOn: $draft.isDone) {
                Text("Completed").font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
            }
            .toggleStyle(.switch)
            .padding(.top, 2)

            HStack(spacing: 8) {
                Button(role: .destructive) {
                    store.delete(draft); dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 13))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    store.update(draft); focus.start(task: draft); dismiss()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button {
                    store.update(draft); dismiss()
                } label: {
                    Text("Save")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    private func field<Content: View>(_ label: String,
                                      @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            content()
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

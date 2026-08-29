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
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
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
                // Focus-time editor.
                field("Focus time") {
                    Stepper(value: $draft.estimateMinutes, in: 5...180, step: 5) {
                        Text("\(draft.estimateMinutes) min")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textPrimary)
                    }
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

            HStack {
                Button(role: .destructive) {
                    store.delete(draft); dismiss()
                } label: {
                    Label("Delete", systemImage: "trash").font(.system(size: 13))
                }
                Spacer()
                Button {
                    store.update(draft); focus.start(task: draft); dismiss()
                } label: {
                    Label("Start", systemImage: "play.fill").font(.system(size: 13, weight: .semibold))
                }
                Button {
                    store.update(draft); dismiss()
                } label: {
                    Text("Save").font(.system(size: 13, weight: .semibold))
                }
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

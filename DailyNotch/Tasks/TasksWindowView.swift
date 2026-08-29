import SwiftUI

/// The big window: month calendar on the left, the selected day's tasks on the
/// right with a Day / Unscheduled toggle and an inline add-task form.
struct TasksWindowView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var focus: FocusTimer

    @State private var selectedDate = Date()
    @State private var tab: Tab = .day
    @State private var showAddForm = false
    @State private var draftTitle = ""
    @State private var draftNotes = ""
    @State private var editingTask: Task?
    @State private var showSettings = false

    enum Tab: String, CaseIterable { case day = "Day", unscheduled = "Unscheduled" }

    private var listedTasks: [Task] {
        tab == .day ? store.tasks(on: selectedDate) : store.unscheduled
    }

    var body: some View {
        HStack(spacing: 0) {
            // ---- Left: calendar ----
            VStack(spacing: 12) {
                HStack {
                    Label("Tasks", systemImage: "checklist")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }
                CalendarView(selectedDate: $selectedDate)
                Spacer()
                Button("Today") { selectedDate = Date() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(16)
            .frame(width: 320)

            Divider().overlay(Color.white.opacity(0.08))

            // ---- Right: day list ----
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(headerTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Picker("", selection: $tab) {
                        ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .labelsHidden()
                }

                List {
                    ForEach(listedTasks) { task in
                        TaskRow(task: task) { editingTask = task }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }
                    .onMove { source, destination in
                        store.moveTasks(in: listedTasks, from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer(minLength: 0)

                if showAddForm {
                    addForm
                } else {
                    Button {
                        withAnimation { showAddForm = true }
                    } label: {
                        Text("Add a task")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 760, minHeight: 480)
        .background(Color.black)
        .preferredColorScheme(.dark)
        .sheet(item: $editingTask) { task in
            TaskDetailView(task: task)
                .environmentObject(store)
                .environmentObject(focus)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
        }
        .onAppear { consumePendingOpen() }
        .onChange(of: store.pendingOpenTaskID) { _, _ in consumePendingOpen() }
    }

    /// Open the detail sheet when the dashboard requested a specific task.
    private func consumePendingOpen() {
        guard let id = store.pendingOpenTaskID,
              let task = store.tasks.first(where: { $0.id == id }) else { return }
        editingTask = task
        store.pendingOpenTaskID = nil
    }

    private var headerTitle: String {
        Calendar.current.isDateInToday(selectedDate) ? "Today" : selectedDate.formatted(.dateTime.month().day())
    }

    private var addForm: some View {
        VStack(spacing: 8) {
            TextField("Task title", text: $draftTitle)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent, lineWidth: 1))
            HStack(spacing: 8) {
                TextField("Notes (optional)", text: $draftNotes)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
                Button("Add") { commitDraft() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 8))
                Button("Cancel") { resetDraft() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func commitDraft() {
        store.add(title: draftTitle, notes: draftNotes,
                  date: tab == .day ? selectedDate : nil)
        resetDraft()
    }

    private func resetDraft() {
        draftTitle = ""; draftNotes = ""
        withAnimation { showAddForm = false }
    }
}

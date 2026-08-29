import SwiftUI
import EventKit

/// The big window: month calendar on the left, the selected day's tasks on the
/// right with a Day / Unscheduled toggle and an inline add-task form.
struct TasksWindowView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var focus: FocusTimer
    @StateObject private var calendar = CalendarAuthModel()

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

                calendarSection

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
        .onAppear {
            consumePendingOpen()
            calendar.refresh()
        }
        .onChange(of: store.pendingOpenTaskID) { _, _ in consumePendingOpen() }
    }

    // MARK: - Calendar section

    @ViewBuilder private var calendarSection: some View {
        switch calendar.state {
        case .notDetermined:
            calendarBanner(
                icon: "calendar.badge.plus",
                title: "Show today's calendar events",
                detail: "We read your events — we never write to them.",
                action: "Connect calendar"
            ) {
                _Concurrency.Task { await calendar.requestAccess() }
            }
        case .denied, .restricted:
            calendarBanner(
                icon: "calendar.badge.exclamationmark",
                title: "Calendar access denied",
                detail: "Open System Settings › Privacy & Security › Calendars to grant access.",
                action: "Open System Settings"
            ) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
        case .authorized:
            if !calendar.events.isEmpty {
                eventsList
            }
        }
    }

    private func calendarBanner(icon: String,
                                title: String,
                                detail: String,
                                action: String,
                                perform: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.accent)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                Button(action) { perform() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 10))
    }

    private var eventsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Today")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(calendar.events.count) event\(calendar.events.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
            }
            VStack(spacing: 4) {
                ForEach(calendar.events, id: \.eventIdentifier) { event in
                    eventRow(event)
                }
            }
        }
    }

    private func eventRow(_ event: EKEvent) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(nsColor: event.calendar.color))
                .frame(width: 6, height: 6)
            Text(event.startDate.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 60, alignment: .leading)
            Text(event.title ?? "(untitled)")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
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

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

    // Focus management for the add-task form. Set to true when the form
    // appears so the user can start typing the title without a second click.
    @FocusState private var titleFocused: Bool

    // Custom drag bookkeeping — same shape as the notch so a reorder feels
    // consistent in both surfaces. `listedTasks` is the filtered+sorted
    // array the user is looking at, and `targetIndex` is where the dragged
    // row would land if released right now.
    @State private var draggingFrom: Int?
    @State private var dragOffset: CGFloat = 0
    private let rowGap: CGFloat = 8
    private let rowHeight: CGFloat = 60

    enum Tab: String, CaseIterable { case day = "Day", unscheduled = "Unscheduled" }

    private var listedTasks: [Task] {
        tab == .day ? store.tasks(on: selectedDate) : store.unscheduled
    }

    var body: some View {
        HStack(spacing: 0) {
            // ---- Left: calendar ----
            VStack(spacing: 12) {
                HStack {
                    Text("Tasks")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
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
                    .contentShape(Rectangle())
            }
            .padding(16)
            .frame(width: 320)

            Divider().overlay(Color.white.opacity(0.08))

            // ---- Right: the day's task list ----
            todoPanel
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

    /// The task list: inner Day/Unscheduled toggle, the drag-to-reorder list,
    /// the calendar event feed, and the inline add form.
    @ViewBuilder private var todoPanel: some View {
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

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: rowGap) {
                    ForEach(Array(listedTasks.enumerated()), id: \.element.id) { index, task in
                        TaskRow(
                            task: task,
                            index: index,
                            isDragging: draggingFrom == index,
                            onDragStart: { handleDragStart(index) },
                            onDragChanged: { handleDragChanged($0) },
                            onDragEnd: handleDragEnd,
                            onOpen: { editingTask = task }
                        )
                        .offset(y: offsetForIndex(index))
                        .opacity(draggingFrom != nil && draggingFrom != index ? 0.45 : 1.0)
                        .zIndex(draggingFrom == index ? 1 : 0)
                        .animation(.spring(response: 0.28, dampingFraction: 0.85),
                                   value: targetIndex())
                        .animation(.easeOut(duration: 0.12), value: draggingFrom)
                    }
                }
            }
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
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
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
                    .contentShape(Rectangle())
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
                .focused($titleFocused)
                .padding(10)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.accent, lineWidth: 1))
                .onSubmit { commitDraft() }
                .onChange(of: draftTitle) { _, new in
                    if new.count > Task.titleLimit {
                        draftTitle = String(new.prefix(Task.titleLimit))
                    }
                }
            HStack(spacing: 8) {
                TextField("Notes (optional)", text: $draftNotes)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
                    .onChange(of: draftNotes) { _, new in
                        if new.count > Task.notesLimit {
                            draftNotes = String(new.prefix(Task.notesLimit))
                        }
                    }
                Button("Add") { commitDraft() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                Button("Cancel") { resetDraft() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
            }
            HStack(spacing: 10) {
                Spacer()
                counter("Title", draftTitle.count, Task.titleLimit)
                counter("Notes", draftNotes.count, Task.notesLimit)
            }
        }
        // Focus the title field as soon as the form is in the hierarchy so
        // the user can start typing immediately after tapping "Add a task".
        .onAppear { titleFocused = true }
    }

    private func counter(_ label: String, _ count: Int, _ limit: Int) -> some View {
        Text("\(label) \(count)/\(limit)")
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(count >= limit ? Theme.accent : Theme.textSecondary)
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

    // MARK: - Custom drag bookkeeping (mirrors the notch panel)

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
                // `move(toOffset:)` inserts *before* the given offset, so a
                // downward move needs +1 to actually land past its new
                // neighbor (otherwise it stops one slot short of the bottom).
                let dest = to > from ? to + 1 : to
                store.moveTasks(in: listedTasks, from: IndexSet(integer: from), to: dest)
            }
        }
        draggingFrom = nil
        dragOffset = 0
    }

    private func targetIndex() -> Int {
        guard let from = draggingFrom else { return 0 }
        let total = listedTasks.count
        guard total > 0 else { return 0 }
        let stride = rowHeight + rowGap
        // Center-based: the row whose center is closest to the dragged row's
        // center wins. No half-stride rounding flicker — the target only
        // flips when the dragged row's center actually crosses a neighbor's.
        let draggedCenter = CGFloat(from) * stride + rowHeight / 2 + dragOffset
        var best = from
        var bestDist = CGFloat.greatestFiniteMagnitude
        for i in 0..<total {
            let center = CGFloat(i) * stride + rowHeight / 2
            let d = abs(draggedCenter - center)
            if d < bestDist { bestDist = d; best = i }
        }
        return best
    }

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

import Foundation
import SwiftUI

/// Single source of truth for tasks + focus sessions, persisted to JSON in
/// Application Support. All mutations happen on the main actor.
@MainActor
final class Store: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var sessions: [FocusSession] = []

    /// Routing bus: set to a task id to request the Tasks window open its detail.
    @Published var pendingOpenTaskID: UUID?

    /// Called when a task is completed or deleted so dependents (the focus timer)
    /// can stop any running session for it. Wired up by the app. `record` says
    /// whether the in-flight session should still be persisted (true on complete,
    /// false on delete — a deleted task has nowhere to count time against).
    var onTaskDeactivated: (_ id: UUID, _ record: Bool) -> Void = { _, _ in }

    private let fileURL: URL

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DailyNotch", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("data.json")
        load()
    }

    // MARK: - Task operations

    func add(title: String, notes: String = "", estimate: Int = 25, date: Date? = Date()) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let nextOrder = (tasks.map(\.sortOrder).max() ?? 0) + 1024
        tasks.append(Task(title: title, notes: notes, scheduledDate: date,
                          estimateMinutes: estimate, sortOrder: nextOrder))
        save()
    }

    func update(_ task: Task) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx] = task
        save()
    }

    func delete(_ task: Task) {
        // Drop any running timer for this task first, without recording time
        // against a task that's about to disappear.
        onTaskDeactivated(task.id, false)
        tasks.removeAll { $0.id == task.id }
        save()
    }

    func toggleDone(_ task: Task) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isDone.toggle()
        // Completing a task stops its running session (resets the progress line)
        // and keeps the focus time it earned.
        if tasks[idx].isDone { onTaskDeactivated(task.id, true) }
        save()
    }

    /// Reorder tasks within a visible list (e.g. today's tasks or the
    /// unscheduled bucket). The caller passes the list the user is looking at
    /// so the source/destination indices line up with what they see; we
    /// re-stamp the moved tasks' `sortOrder` in their new positions using
    /// 1024-step spacing. Collisions across lists don't matter because each
    /// list is sorted independently.
    func moveTasks(in list: [Task], from source: IndexSet, to destination: Int) {
        var working = list
        working.move(fromOffsets: source, toOffset: destination)
        for (i, t) in working.enumerated() {
            if let idx = tasks.firstIndex(where: { $0.id == t.id }) {
                tasks[idx].sortOrder = Double(i + 1) * 1024
            }
        }
        save()
    }

    // MARK: - Queries

    /// Sort key: prefer user-controlled `sortOrder`; break ties on `createdAt`
    /// so legacy tasks (sortOrder == 0) and same-rank new tasks stay stable.
    private func sortKey(_ t: Task) -> (Double, Date) { (t.sortOrder, t.createdAt) }

    func tasks(on day: Date) -> [Task] {
        let cal = Calendar.current
        return tasks
            .filter { $0.scheduledDate.map { cal.isDate($0, inSameDayAs: day) } ?? false }
            .sorted { sortKey($0) < sortKey($1) }
    }

    var unscheduled: [Task] {
        tasks.filter { $0.scheduledDate == nil }
            .sorted { sortKey($0) < sortKey($1) }
    }

    /// Days (normalized to start-of-day) that have at least one focus session.
    var activeDays: Set<Date> {
        let cal = Calendar.current
        return Set(sessions.map { cal.startOfDay(for: $0.startedAt) })
    }

    /// Consecutive-day streak ending today (or yesterday).
    var currentStreak: Int {
        let cal = Calendar.current
        let active = activeDays
        var streak = 0
        var day = cal.startOfDay(for: Date())
        if !active.contains(day) {
            day = cal.date(byAdding: .day, value: -1, to: day)!
            if !active.contains(day) { return 0 }
        }
        while active.contains(day) {
            streak += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    func recordSession(_ session: FocusSession) {
        sessions.append(session)
        if let tid = session.taskId, let idx = tasks.firstIndex(where: { $0.id == tid }) {
            tasks[idx].focusedSeconds += Int(session.duration)
        }
        save()
    }

    // MARK: - Persistence

    private struct Payload: Codable { var tasks: [Task]; var sessions: [FocusSession] }

    func save() {
        let payload = Payload(tasks: tasks, sessions: sessions)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
        tasks = payload.tasks
        sessions = payload.sessions
        // One-shot migration: any task with sortOrder == 0 came from a pre-reorder
        // data file. Give each one a stable value in the persisted order so the
        // first display matches what the user had, and reorders start working.
        if tasks.contains(where: { $0.sortOrder == 0 }) {
            for i in tasks.indices {
                tasks[i].sortOrder = Double(i + 1) * 1024
            }
            save()
        }
    }
}

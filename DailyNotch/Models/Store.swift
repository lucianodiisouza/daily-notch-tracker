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
        if tasks.isEmpty { seedSampleData() }
    }

    // MARK: - Task operations

    func add(title: String, notes: String = "", estimate: Int = 25, date: Date? = Date()) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        tasks.append(Task(title: title, notes: notes, scheduledDate: date, estimateMinutes: estimate))
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

    // MARK: - Queries

    func tasks(on day: Date) -> [Task] {
        let cal = Calendar.current
        return tasks
            .filter { $0.scheduledDate.map { cal.isDate($0, inSameDayAs: day) } ?? false }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var unscheduled: [Task] {
        tasks.filter { $0.scheduledDate == nil }.sorted { $0.createdAt < $1.createdAt }
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
    }

    private func seedSampleData() {
        add(title: "Design Daily", notes: "Design, and brainstorming for new upcoming products.", estimate: 5)
        add(title: "Fix Bug for Screen", notes: "Fix bug #7 from Sentry reported.", estimate: 25)

        // Seed varied activity so the graded heatmap + streak look alive on first
        // run: a clean 5-day current streak (days 1...5), a gap at day 6, then a
        // scattered history with 0-4 sessions/day.
        let cal = Calendar.current
        func addSessions(_ count: Int, daysAgo: Int) {
            guard count > 0, let day = cal.date(byAdding: .day, value: -daysAgo, to: Date()) else { return }
            for _ in 0..<count {
                sessions.append(FocusSession(startedAt: day,
                                             endedAt: day.addingTimeInterval(1500),
                                             completed: true))
            }
        }
        let currentStreakCounts = [1: 2, 2: 4, 3: 1, 4: 3, 5: 2]   // days 1...5 = 5-day streak
        for (daysAgo, count) in currentStreakCounts { addSessions(count, daysAgo: daysAgo) }
        // day 6 intentionally empty to bound the streak at 5.
        let history = [3, 1, 0, 2, 4, 1, 0, 0, 3, 2, 1, 0, 4, 2, 0, 1, 3, 0, 2, 1, 4, 0, 1, 2, 0, 3, 1]
        for (i, count) in history.enumerated() { addSessions(count, daysAgo: 7 + i) }
        save()
    }
}

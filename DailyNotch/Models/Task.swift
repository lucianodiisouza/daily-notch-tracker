import Foundation

/// A single to-do / focus task.
struct Task: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var notes: String = ""
    /// The calendar day this task is scheduled for. `nil` == unscheduled.
    var scheduledDate: Date?
    /// Planned focus duration in minutes (the Pomodoro estimate, e.g. 25).
    var estimateMinutes: Int = 25
    var isDone: Bool = false
    var createdAt: Date = Date()
    /// Total focused seconds accumulated against this task.
    var focusedSeconds: Int = 0

    var estimateLabel: String {
        estimateMinutes >= 60
            ? "\(estimateMinutes / 60)h\(estimateMinutes % 60 == 0 ? "" : "\(estimateMinutes % 60)m")"
            : "\(estimateMinutes)m"
    }
}

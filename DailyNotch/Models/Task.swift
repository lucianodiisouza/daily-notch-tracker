import Foundation

/// A single to-do / focus task.
struct Task: Identifiable, Codable, Hashable {
    /// Max characters accepted in the title / notes fields.
    static let titleLimit = 150
    static let notesLimit = 500

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
    /// User-controlled display order. Tasks sort by this ascending; ties break
    /// on `createdAt`. Legacy tasks (decoded from a pre-reorder data file) come
    /// back with `0` and `Store.load()` migrates them to a stable range.
    var sortOrder: Double = 0

    var estimateLabel: String {
        estimateMinutes >= 60
            ? "\(estimateMinutes / 60)h\(estimateMinutes % 60 == 0 ? "" : "\(estimateMinutes % 60)m")"
            : "\(estimateMinutes)m"
    }

    init(title: String,
         notes: String = "",
         scheduledDate: Date? = Date(),
         estimateMinutes: Int = 25,
         isDone: Bool = false,
         createdAt: Date = Date(),
         focusedSeconds: Int = 0,
         sortOrder: Double = 0) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.scheduledDate = scheduledDate
        self.estimateMinutes = estimateMinutes
        self.isDone = isDone
        self.createdAt = createdAt
        self.focusedSeconds = focusedSeconds
        self.sortOrder = sortOrder
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, notes, scheduledDate, estimateMinutes, isDone
        case createdAt, focusedSeconds, sortOrder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        notes = try c.decode(String.self, forKey: .notes)
        scheduledDate = try c.decodeIfPresent(Date.self, forKey: .scheduledDate)
        estimateMinutes = try c.decode(Int.self, forKey: .estimateMinutes)
        isDone = try c.decode(Bool.self, forKey: .isDone)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        focusedSeconds = try c.decode(Int.self, forKey: .focusedSeconds)
        // Missing field == pre-reorder data; default 0 lets `Store.load()`
        // assign stable values once.
        sortOrder = try c.decodeIfPresent(Double.self, forKey: .sortOrder) ?? 0
    }
}

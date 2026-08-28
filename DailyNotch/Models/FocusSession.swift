import Foundation

/// A completed (or aborted) focus block, used to compute the streak heatmap.
struct FocusSession: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var taskId: UUID?
    var startedAt: Date
    var endedAt: Date
    /// Whether the block ran to completion (vs. stopped early).
    var completed: Bool

    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }
}

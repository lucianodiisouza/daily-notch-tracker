import Foundation

/// User-tunable focus-timer knobs. Persisted in the same JSON file as tasks +
/// sessions so the app boots with the user's last choice.
struct FocusSettings: Codable, Equatable {
    /// Default focus block length in minutes. Used when a task doesn't have a
    /// per-task estimate (or as the default for newly added tasks).
    var focusMinutes: Int = 25
    /// Whether to post a macOS user notification when a focus block completes.
    var notificationsEnabled: Bool = true
    /// Whether to play the system beep at the end of a focus block.
    var playSound: Bool = true
    /// Whether the collapsed counting pill draws the accent progress timeline.
    /// When off, the pill sits flush at the exact hardware-notch height and
    /// shows only the time + task name (no overhang, no progress line).
    var showTimeline: Bool = true

    static let `default` = FocusSettings()

    /// Clamp the focus range to the same bounds the TaskDetailView uses, so
    /// the settings sheet and the per-task editor can never disagree.
    static let focusRange: ClosedRange<Int> = 1...180
}

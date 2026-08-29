import Foundation

/// User-tunable Pomodoro knobs. Persisted in the same JSON file as tasks +
/// sessions so the app boots with the user's last choice.
struct FocusSettings: Codable, Equatable {
    /// Default focus block length in minutes. Used when a task doesn't have a
    /// per-task estimate (or as the default for newly added tasks).
    var focusMinutes: Int = 25
    /// Length of the break between focus blocks. Stored now, wired into the
    /// timer in a follow-up that introduces explicit break sessions.
    var breakMinutes: Int = 5
    /// Whether to post a macOS user notification when a focus block completes.
    var notificationsEnabled: Bool = true
    /// Whether to play the system beep at the end of a focus block.
    var playSound: Bool = true

    static let `default` = FocusSettings()

    /// Clamp the focus range to the same bounds the TaskDetailView uses, so
    /// the settings sheet and the per-task editor can never disagree.
    static let focusRange: ClosedRange<Int> = 5...180
    static let breakRange: ClosedRange<Int> = 1...60
}

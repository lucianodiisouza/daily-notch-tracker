import Foundation

/// User-tunable Pomodoro knobs. Persisted in the same JSON file as tasks +
/// sessions so the app boots with the user's last choice.
struct FocusSettings: Codable, Equatable {
    /// Default focus block length in minutes. Used when a task doesn't have a
    /// per-task estimate (or as the default for newly added tasks).
    var focusMinutes: Int = 25
    /// Length of the short break between focus blocks in a Pomodoro cycle.
    var breakMinutes: Int = 5
    /// Length of the long break that closes out a full Pomodoro cycle.
    var longBreakMinutes: Int = 15
    /// Whether to post a macOS user notification when a focus block completes.
    var notificationsEnabled: Bool = true
    /// Whether to play the system beep at the end of a focus block.
    var playSound: Bool = true

    static let `default` = FocusSettings()

    /// Clamp the focus range to the same bounds the TaskDetailView uses, so
    /// the settings sheet and the per-task editor can never disagree.
    static let focusRange: ClosedRange<Int> = 1...180
    static let breakRange: ClosedRange<Int> = 1...60
    static let longBreakRange: ClosedRange<Int> = 1...120

    /// Number of work sessions in one full Pomodoro cycle (the long break
    /// fires after the last one).
    static let sessionsPerCycle: Int = 3
}

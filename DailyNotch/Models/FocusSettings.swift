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
    /// Override the system accent color for the progress timeline with an
    /// animated rainbow (RGB) cycle plus a matching glow. Independent of
    /// `showTimeline` — only takes effect while the timeline is drawn.
    var rainbowTimeline: Bool = false
    /// Minimal collapsed pill: hide the countdown + task title so the pill only
    /// contours the hardware notch. The progress timeline is independent
    /// (governed by `showTimeline`).
    var minimalMode: Bool = false

    static let `default` = FocusSettings()

    /// Clamp the focus range to the same bounds the TaskDetailView uses, so
    /// the settings sheet and the per-task editor can never disagree.
    static let focusRange: ClosedRange<Int> = 1...180

    // MARK: - Tolerant decoding
    //
    // The synthesized decoder throws `keyNotFound` for any missing key, even
    // when the property has a default. Since this struct is persisted and grows
    // new fields over time, an older on-disk file (written before a field
    // existed) would otherwise fail to decode — taking the whole payload with
    // it. Decode every key `IfPresent` so missing fields fall back to defaults.

    private enum CodingKeys: String, CodingKey {
        case focusMinutes, notificationsEnabled, playSound
        case showTimeline, rainbowTimeline, minimalMode
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = FocusSettings.default
        focusMinutes = try c.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? d.focusMinutes
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? d.notificationsEnabled
        playSound = try c.decodeIfPresent(Bool.self, forKey: .playSound) ?? d.playSound
        showTimeline = try c.decodeIfPresent(Bool.self, forKey: .showTimeline) ?? d.showTimeline
        rainbowTimeline = try c.decodeIfPresent(Bool.self, forKey: .rainbowTimeline) ?? d.rainbowTimeline
        minimalMode = try c.decodeIfPresent(Bool.self, forKey: .minimalMode) ?? d.minimalMode
    }
}

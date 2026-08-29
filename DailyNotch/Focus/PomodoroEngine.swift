import Foundation
import SwiftUI
import AppKit

/// Multi-phase Pomodoro cycle engine. Independent of `FocusTimer` (which is
/// the per-task single-block timer). One full cycle is:
///
///     work → shortBreak → work → shortBreak → work → longBreak
///
/// Durations come from `FocusSettings` so the user controls the cadence. The
/// cycle ends after the long break completes; the user can `start()` again
/// for another round.
@MainActor
final class PomodoroEngine: ObservableObject {
    enum Phase: String, Equatable {
        case work, shortBreak, longBreak

        var label: String {
            switch self {
            case .work:       return "Focus"
            case .shortBreak: return "Short break"
            case .longBreak:  return "Long break"
            }
        }
    }

    enum State: Equatable { case idle, running, paused, finished }

    @Published private(set) var state: State = .idle
    @Published private(set) var phase: Phase = .work
    /// Which work session in the current cycle (1…`sessionsPerCycle`).
    @Published private(set) var cycle: Int = 1
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var total: TimeInterval = 0

    private var timer: Timer?
    private unowned let store: Store

    init(store: Store) { self.store = store }

    var isActive: Bool { state == .running || state == .paused }
    var isFinished: Bool { state == .finished }

    /// 0…1 elapsed fraction for the phase's progress ring/bar.
    var progress: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, (total - remaining) / total))
    }

    var timeLabel: String {
        let t = max(0, Int(remaining.rounded()))
        return String(format: "%02d:%02d", t / 60, t % 60)
    }

    var color: Color {
        switch phase {
        case .work:       return Theme.pomodoroWork
        case .shortBreak: return Theme.pomodoroShortBreak
        case .longBreak:  return Theme.pomodoroLongBreak
        }
    }

    // MARK: - Controls

    /// Begin (or restart) a full cycle. Resets to the first work phase.
    func start() {
        if state == .paused { resume(); return }
        cycle = 1
        beginPhase(.work)
        resume()
    }

    func togglePause() {
        switch state {
        case .running: pause()
        case .paused:  resume()
        default:       break
        }
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        timer?.invalidate()
        timer = nil
    }

    private func resume() {
        state = .running
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// End the cycle right now (no record, no notification).
    func stop() {
        timer?.invalidate()
        timer = nil
        state = .idle
        remaining = 0
        total = 0
    }

    /// Skip the current phase and jump straight to the next one.
    func skip() {
        guard isActive else { return }
        advancePhase()
    }

    // MARK: - Cycle machinery

    private func beginPhase(_ p: Phase) {
        phase = p
        let minutes: Int
        switch p {
        case .work:       minutes = store.settings.focusMinutes
        case .shortBreak: minutes = store.settings.breakMinutes
        case .longBreak:  minutes = store.settings.longBreakMinutes
        }
        total = TimeInterval(max(1, minutes) * 60)
        remaining = total
    }

    private func tick() {
        guard state == .running else { return }
        remaining = max(0, remaining - 1)
        if remaining <= 0 { advancePhase() }
    }

    private func advancePhase() {
        if store.settings.playSound { NSSound.beep() }
        if store.settings.notificationsEnabled {
            NotificationService.shared.postPomodoroPhase(phase: phase)
        }

        switch phase {
        case .work:
            // After the final work session, take the long break. Otherwise
            // take a short one.
            if cycle >= FocusSettings.sessionsPerCycle {
                beginPhase(.longBreak)
            } else {
                beginPhase(.shortBreak)
            }
        case .shortBreak:
            // Short break over — bump the cycle counter and start the next
            // work session.
            cycle += 1
            beginPhase(.work)
        case .longBreak:
            // Long break over — the cycle is complete.
            finishCycle()
        }
    }

    private func finishCycle() {
        timer?.invalidate()
        timer = nil
        state = .finished
        remaining = 0
        total = 0
    }
}

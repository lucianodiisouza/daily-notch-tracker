import Foundation
import SwiftUI

/// Pomodoro-style focus engine. Drives the collapsed-pill countdown + progress bar.
@MainActor
final class FocusTimer: ObservableObject {
    enum State: Equatable { case idle, running, paused }

    @Published private(set) var state: State = .idle
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var total: TimeInterval = 0
    @Published private(set) var activeTask: Task?

    private var timer: Timer?
    private var startedAt: Date?
    private unowned let store: Store

    init(store: Store) { self.store = store }

    var isActive: Bool { state != .idle }

    /// 0…1 elapsed fraction, for the progress bar.
    var progress: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, (total - remaining) / total))
    }

    var timeLabel: String {
        let t = max(0, Int(remaining.rounded()))
        return String(format: "%02d:%02d", t / 60, t % 60)
    }

    func start(task: Task) {
        stop(record: state != .idle)   // wrap up any prior block first
        activeTask = task
        total = TimeInterval(max(1, task.estimateMinutes) * 60)
        remaining = total
        startedAt = Date()
        resume()
    }

    func togglePause() {
        switch state {
        case .running: pause()
        case .paused:  resume()
        case .idle:    break
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

    private func tick() {
        guard state == .running else { return }
        remaining = max(0, remaining - 1)
        if remaining <= 0 { complete() }
    }

    private func complete() {
        finishSession(completed: true)
        NSSound.beep()
        reset()
    }

    /// Stop the current block. `record` persists a session if one was in flight.
    func stop(record: Bool = true) {
        if record { finishSession(completed: false) }
        reset()
    }

    /// Stop the timer only if the running session belongs to `id` (task completed
    /// or deleted). No-op otherwise.
    func stopIfActive(_ id: UUID, record: Bool) {
        guard isActive, activeTask?.id == id else { return }
        stop(record: record)
    }

    private func finishSession(completed: Bool) {
        guard let startedAt else { return }
        let session = FocusSession(taskId: activeTask?.id,
                                   startedAt: startedAt,
                                   endedAt: Date(),
                                   completed: completed)
        store.recordSession(session)
    }

    private func reset() {
        timer?.invalidate()
        timer = nil
        state = .idle
        remaining = 0
        total = 0
        activeTask = nil
        startedAt = nil
    }
}

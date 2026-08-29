import Foundation
import EventKit

/// Tiny observable wrapper around `CalendarService` so SwiftUI views can
/// react to authorization changes and today's event list with a single
/// `refresh()` call.
@MainActor
final class CalendarAuthModel: ObservableObject {
    @Published var state: CalendarService.AuthState = .notDetermined
    @Published var events: [EKEvent] = []

    /// The day whose events are currently loaded. Kept so `requestAccess()`
    /// and the live-change observer can refresh the same day the view is
    /// showing.
    private var loadedDate = Date()

    /// Token for the `.EKEventStoreChanged` observer, removed on deinit.
    private var changeObserver: NSObjectProtocol?

    init() {
        refresh(for: loadedDate)
        // EventKit posts this (possibly off the main thread) whenever any
        // calendar data changes — an event added, edited, or deleted, here or
        // in another app. Reload the day we're showing so the feed stays live.
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: nil, queue: nil
        ) { [weak self] _ in
            _Concurrency.Task { @MainActor in
                guard let self else { return }
                self.refresh(for: self.loadedDate)
            }
        }
    }

    deinit {
        if let changeObserver { NotificationCenter.default.removeObserver(changeObserver) }
    }

    /// Re-read the current auth state and (if authorized) the events for `date`.
    func refresh(for date: Date) {
        loadedDate = date
        state = CalendarService.shared.authState()
        events = CalendarService.shared.events(on: date)
    }

    /// Request EventKit access and refresh on completion. No-op if already
    /// authorized or denied — the system prompt only shows once.
    func requestAccess() async {
        _ = await CalendarService.shared.requestAccess()
        refresh(for: loadedDate)
    }
}

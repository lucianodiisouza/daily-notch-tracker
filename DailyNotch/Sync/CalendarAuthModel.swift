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
    /// can refresh the same day the view is showing after a grant.
    private var loadedDate = Date()

    init() { refresh(for: loadedDate) }

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

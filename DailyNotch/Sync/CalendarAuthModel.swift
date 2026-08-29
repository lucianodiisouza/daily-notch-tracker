import Foundation
import EventKit

/// Tiny observable wrapper around `CalendarService` so SwiftUI views can
/// react to authorization changes and today's event list with a single
/// `refresh()` call.
@MainActor
final class CalendarAuthModel: ObservableObject {
    @Published var state: CalendarService.AuthState = .notDetermined
    @Published var events: [EKEvent] = []

    init() { refresh() }

    /// Re-read the current auth state and (if authorized) the events list.
    func refresh() {
        state = CalendarService.shared.authState()
        events = CalendarService.shared.todaysEvents()
    }

    /// Request EventKit access and refresh on completion. No-op if already
    /// authorized or denied — the system prompt only shows once.
    func requestAccess() async {
        _ = await CalendarService.shared.requestAccess()
        refresh()
    }
}

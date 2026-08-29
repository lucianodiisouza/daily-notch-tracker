import Foundation
import EventKit

/// Read-only access to today's calendar events via EventKit. We do not write
/// back to the user's calendars — this is a "what else is on your plate" view
/// alongside the to-do list, not a two-way sync.
final class CalendarService {
    static let shared = CalendarService()

    enum AuthState {
        case authorized, denied, restricted, notDetermined
    }

    private let store = EKEventStore()

    /// Current EventKit permission state. On macOS 14+ `requestFullAccessToEvents`
    /// is the supported call; the older `requestAccess(to:)` is deprecated.
    func authState() -> AuthState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .authorized
        case .denied:     return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        case .writeOnly:  return .authorized   // shouldn't happen on macOS, but be permissive
        @unknown default: return .notDetermined
        }
    }

    /// Request permission to read events. The system shows the prompt only
    /// once per install; subsequent calls return the current grant state.
    @discardableResult
    func requestAccess() async -> Bool {
        do { return try await store.requestFullAccessToEvents() }
        catch { return false }
    }

    /// All events scheduled for today, sorted by start time, across all
    /// calendars the user has granted access to. Returns an empty array when
    /// the user hasn't granted access.
    func todaysEvents() -> [EKEvent] {
        guard authState() == .authorized else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
    }
}

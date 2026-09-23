import Foundation
import UserNotifications

/// Wraps `UNUserNotificationCenter` so the rest of the app can request
/// authorization once and post a single "focus block complete" notification
/// without dealing with the delegate dance.
final class NotificationService {
    static let shared = NotificationService()

    /// Ask the user for notification permission. The system only shows the
    /// prompt once per install; subsequent calls return the current grant
    /// state without re-prompting, so it's safe to call from app launch and
    /// again from each focus block start.
    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Whether macOS currently lets DailyNotch post notifications. `nil` while
    /// the user hasn't been asked yet.
    func isAuthorized() async -> Bool? {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return nil
        case .denied: return false
        default: return true
        }
    }

    /// Post the "focus block complete" notification immediately. Caller
    /// checks `FocusSettings.notificationsEnabled` before invoking.
    func postFocusComplete(taskTitle: String?) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Focus block complete")
        if let task = taskTitle, !task.isEmpty {
            content.body = String(localized: "You finished \u{201C}\(task)\u{201D}. Time for a break.")
        } else {
            content.body = String(localized: "Time for a break.")
        }
        // Silent on purpose: the focus timer plays its own chime when the
        // "Play sound" setting is on, so a notification sound would double it
        // (and ignore that setting when it is off).
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "focus.complete.\(UUID().uuidString)",
            content: content,
            trigger: nil)   // deliver immediately
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

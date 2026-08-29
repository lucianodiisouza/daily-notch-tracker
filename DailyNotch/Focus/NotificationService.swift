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

    /// Post the "focus block complete" notification immediately. Caller
    /// checks `FocusSettings.notificationsEnabled` before invoking.
    func postFocusComplete(taskTitle: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Focus block complete"
        if let task = taskTitle, !task.isEmpty {
            content.body = "Time for a break — finished \u{201C}\(task)\u{201D}."
        } else {
            content.body = "Time for a break."
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "focus.complete.\(UUID().uuidString)",
            content: content,
            trigger: nil)   // deliver immediately
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

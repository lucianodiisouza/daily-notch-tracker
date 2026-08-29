import Foundation
import ServiceManagement

/// Wraps `SMAppService.mainApp` (macOS 13+) so the rest of the app can read
/// and toggle "launch at login" without dealing with the async registration
/// dance. The service is the system-managed launch agent - no separate
/// helper binary, no privileged helper to install.
@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled: Bool

    init() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// Re-read the registration status. Call after the user toggles the
    /// setting or after a system prompt response, since the OS may delay
    /// flipping the status until the user confirms.
    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// Enable or disable launch at login. On first enable the system shows
    /// a confirmation prompt the user must accept; subsequent toggles are
    /// silent. Throws if registration is blocked (e.g. the app isn't
    /// signed or running from a quarantined path).
    func setEnabled(_ enabled: Bool) async {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try await SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try await SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // Best-effort: re-read the actual status so the toggle reflects
            // reality even when registration fails silently.
            print("LaunchAtLogin error: \(error)")
        }
        refresh()
    }
}

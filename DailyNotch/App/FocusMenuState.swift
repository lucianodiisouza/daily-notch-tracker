import Foundation
import Combine

/// Tiny observable wrapper that mirrors the focus timer's running state so
/// the menu bar can show a live "Start focus" / "Stop focus" label. The
/// `MenuBarExtra` body re-evaluates whenever this changes, which the
/// `@NSApplicationDelegateAdaptor` does not do on its own for the
/// `AppDelegate`'s properties.
@MainActor
final class FocusMenuState: ObservableObject {
    @Published private(set) var isFocusing: Bool = false
    static let shared = FocusMenuState()

    func update(isFocusing: Bool) {
        self.isFocusing = isFocusing
    }
}

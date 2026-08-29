import Carbon.HIToolbox
import AppKit

/// Wraps Carbon's `RegisterEventHotKey` so the rest of the app can install a
/// system-wide keyboard shortcut without dealing with HIToolbox directly.
///
/// One instance = one binding. `unregister()` tears down both the hotkey and
/// the event handler so callers can re-register with a new combo. Carbon
/// dispatches the callback on the main thread; we bounce through the main
/// queue anyway so callers stay free of threading concerns.
final class GlobalHotkey {
    typealias Handler = () -> Void

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var handler: Handler?

    /// 'NOTC' in big-endian ASCII — the app's four-char signature for hotkey IDs.
    private let signature: OSType = 0x4E4F5443
    private let id: UInt32

    init(id: UInt32 = 1) {
        self.id = id
    }

    deinit { unregister() }

    /// Register a global shortcut. `carbonModifiers` is a Carbon modifier mask
    /// (`cmdKey | shiftKey | optionKey | controlKey`).
    /// Returns `true` if both the event handler and the hotkey installed cleanly.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping Handler) -> Bool {
        unregister()
        self.handler = handler

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            globalHotkeyEventHandler,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef)
        guard installStatus == noErr else { return false }

        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef)
        return registerStatus == noErr
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let h = eventHandlerRef {
            RemoveEventHandler(h)
            eventHandlerRef = nil
        }
        handler = nil
    }

    fileprivate func dispatchHandler() {
        let h = handler
        DispatchQueue.main.async { h?() }
    }
}

/// Free C-convention callback so `InstallEventHandler` accepts it. Recovers
/// the owning `GlobalHotkey` via the user-data pointer the caller stashed.
private func globalHotkeyEventHandler(_ callRef: EventHandlerCallRef?,
                                      _ eventRef: EventRef?,
                                      _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
    hotkey.dispatchHandler()
    return noErr
}

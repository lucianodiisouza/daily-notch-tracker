import AppKit
import CoreGraphics

/// Which physical display the notch should anchor to.
///
/// Stored in `FocusSettings` and consumed by `DisplayResolver` at the moment a
/// `NotchViewModel` needs a screen — never cached as an `NSScreen` reference,
/// because screens come and go at runtime.
enum DisplayPreference: Codable, Hashable {
    /// Follow `NSScreen.main` (the display with the focused menu bar). This is
    /// the historical default and preserves the pre-feature behaviour exactly.
    case auto
    /// MacBook's built-in display (`CGDisplayIsBuiltin == true`).
    case builtIn
    /// First connected display that is not built-in. With two externals, picks
    /// the first one in `NSScreen.screens` order; the user can disambiguate via
    /// `.specific(_:)`.
    case external
    /// A specific display, identified by `CGDirectDisplayID`. Persists across
    /// reconnects — the resolver looks it up by ID and falls back when the
    /// display disappears.
    case specific(UInt32)
}

// MARK: - Codable
//
// Encoded as a JSON object so we can attach the display ID for `.specific`:
//   {"type": "auto"}
//   {"type": "builtIn"}
//   {"type": "external"}
//   {"type": "specific", "id": 12345678}
//
// `decodeIfPresent` in `FocusSettings.init(from:)` handles the "field missing
// in old on-disk JSON" case; this initializer is only called when the field
// is present. A missing `id` for `.specific` falls back to `.auto` rather than
// throwing — keeps the whole `Store` payload decodable.

extension DisplayPreference {
    private enum Kind: String, Codable { case auto, builtIn, external, specific }
    private enum CodingKeys: String, CodingKey { case type, id }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .type)
        switch kind {
        case .auto:     self = .auto
        case .builtIn:  self = .builtIn
        case .external: self = .external
        case .specific:
            // Defensive: if `id` is missing or wrong type, fall back to .auto
            // rather than failing the whole Store payload.
            if let id = try? c.decode(UInt32.self, forKey: .id) {
                self = .specific(id)
            } else {
                self = .auto
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .auto:
            try c.encode(Kind.auto, forKey: .type)
        case .builtIn:
            try c.encode(Kind.builtIn, forKey: .type)
        case .external:
            try c.encode(Kind.external, forKey: .type)
        case .specific(let id):
            try c.encode(Kind.specific, forKey: .type)
            try c.encode(id, forKey: .id)
        }
    }
}

// MARK: - NSScreen helpers

extension NSScreen {
    /// Stable per-display identifier from the window server. Returns `nil` for
    /// screens the server hasn't fully initialized (rare; happens briefly
    /// during hot-plug events).
    var displayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    /// `true` for the MacBook's built-in panel. External monitors (and most
    /// iPads / Sidecar) report `false`. Determined via `CGDisplayIsBuiltin` on
    /// the window-server display ID.
    var isBuiltIn: Bool {
        guard let id = displayID else { return false }
        return CGDisplayIsBuiltin(id) != 0
    }

    /// Human-readable name shown in the Settings picker. `localizedName` is
    /// available on macOS 10.15+; fall back to a generic label otherwise.
    var displayName: String {
        if #available(macOS 10.15, *) {
            return localizedName
        }
        if let id = displayID {
            return "Display \(id)"
        }
        return "Display"
    }
}

// MARK: - DisplayResolver

/// Pure-logic lookup from a `DisplayPreference` to the `NSScreen` it should
/// resolve to right now. Stateless and `@MainActor` because `NSScreen.screens`
/// must be touched on the main thread.
@MainActor
enum DisplayResolver {

    /// Resolve the preferred screen. `fallback` is used whenever the preferred
    /// screen is not connected (e.g. external unplugged, clamshell mode). It
    /// itself should never be `nil` — callers pass the existing
    /// `NotchMetrics.primary` screen so behaviour degrades to the historical
    /// "main screen" rule rather than crashing.
    static func resolve(_ preference: DisplayPreference,
                        screens: [NSScreen] = NSScreen.screens,
                        fallback: NSScreen) -> NSScreen {
        switch preference {
        case .auto:
            // Main screen is the one with the keyboard focus / menu bar; falls
            // back to the first connected screen when no window is focused.
            return NSScreen.main ?? screens.first ?? fallback

        case .builtIn:
            return screens.first(where: { $0.isBuiltIn }) ?? NSScreen.main ?? fallback

        case .external:
            return screens.first(where: { !$0.isBuiltIn }) ?? NSScreen.main ?? fallback

        case .specific(let id):
            return screens.first(where: { $0.displayID == id }) ?? NSScreen.main ?? fallback
        }
    }
}

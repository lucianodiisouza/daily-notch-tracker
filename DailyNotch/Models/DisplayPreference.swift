import AppKit
import CoreGraphics

/// Which physical display the notch should anchor to.
///
/// Stored in `FocusSettings` and consumed by `DisplayResolver` at the moment a
/// `NotchViewModel` needs a screen — never cached as an `NSScreen` reference,
/// because screens come and go at runtime.
enum DisplayPreference: Codable, Equatable {
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

// MARK: - Picker source

/// Items for the Settings "Display" picker. The `id` is what gets stored; the
/// `name` is what the user sees. `id == nil` represents a synthetic entry
/// (e.g. "External monitor" when no external is connected — selecting it is
/// pointless but the UI can show it for context).
struct DisplayChoice: Identifiable, Equatable, Hashable {
    let id: UInt32?     // nil ⇒ synthetic (Main, Built-In, External, Auto)
    let name: String
    let subtitle: String?
}

/// Build the picker source from currently-connected screens plus the four
/// always-available synthetic entries (`Auto`, `Built-In`, `External`, plus any
/// already-saved `.specific` that's currently offline).
@MainActor
enum DisplayChoices {
    static func current(saved: DisplayPreference) -> [DisplayChoice] {
        var out: [DisplayChoice] = [
            DisplayChoice(id: nil, name: "Automatic", subtitle: "Follow the active display"),
            DisplayChoice(id: nil, name: "MacBook's built-in", subtitle: builtInSubtitle),
            DisplayChoice(id: nil, name: "External monitor", subtitle: externalSubtitle),
        ]

        // Per-screen entries: real IDs the user can target individually.
        for screen in NSScreen.screens {
            let resolution = "\(Int(screen.frame.width))×\(Int(screen.frame.height))"
            let built = screen.isBuiltIn ? " · built-in" : ""
            out.append(DisplayChoice(
                id: screen.displayID,
                name: screen.displayName,
                subtitle: "\(resolution)\(built)"
            ))
        }

        // If a `.specific(id)` is saved but the display is gone, surface it
        // marked offline so the user can see (and replace) their choice.
        if case .specific(let savedID) = saved,
           !NSScreen.screens.contains(where: { $0.displayID == savedID }) {
            out.append(DisplayChoice(
                id: savedID,
                name: "Saved display (offline)",
                subtitle: "Display ID \(savedID) is no longer connected"
            ))
        }

        return out
    }

    private static var builtInSubtitle: String {
        let n = NSScreen.screens.filter { $0.isBuiltIn }.count
        return n == 0 ? "Not currently connected" : "Connected"
    }

    private static var externalSubtitle: String {
        let n = NSScreen.screens.filter { !$0.isBuiltIn }.count
        switch n {
        case 0: return "No external display connected"
        case 1: return "1 external display connected"
        default: return "\(n) external displays connected"
        }
    }
}

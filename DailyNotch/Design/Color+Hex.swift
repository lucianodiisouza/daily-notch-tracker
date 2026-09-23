import SwiftUI

extension Color {
    /// `#RRGGBB` (or `RRGGBB`) to a color. Anything unparsable is gray.
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        guard digits.count == 6, Scanner(string: digits).scanHexInt64(&value) else {
            self = .gray
            return
        }
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

extension String {
    /// Looks the string up in Localizable.xcstrings. For titles that reach a
    /// view as a `String` variable, which `Text` would otherwise show verbatim.
    var localized: String { String(localized: String.LocalizationValue(self)) }
}

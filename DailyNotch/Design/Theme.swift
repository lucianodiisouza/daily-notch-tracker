import SwiftUI

/// Shared visual language, tuned to match the mockups (black pill, blue accent).
enum Theme {
    static let accent = Color(red: 0.15, green: 0.47, blue: 1.0)     // iOS-style blue
    static let danger = Color(red: 0.95, green: 0.23, blue: 0.23)    // pause red
    static let pill = Color.black
    static let panel = Color(white: 0.10)
    static let panelHover = Color(white: 0.16)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.62)
    static let streakEmpty = Color(white: 0.14)

    static let notchCorner: CGFloat = 22
    static let panelCorner: CGFloat = 14
}

/// A rounded-bottom "notch" shape: flush square top (meets the screen edge),
/// generously rounded bottom corners.
struct NotchShape: Shape {
    var topRadius: CGFloat = 8
    var bottomRadius: CGFloat = Theme.notchCorner

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let tr = min(topRadius, rect.width / 2)
        let br = min(bottomRadius, rect.width / 2)
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // top edge with slight inner curve down into the notch
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - br, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - br),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        _ = tr
        return p
    }
}

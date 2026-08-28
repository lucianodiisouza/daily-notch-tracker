import AppKit

/// Physical measurements of the built-in notch on a given screen.
struct NotchMetrics {
    let screen: NSScreen
    /// Width of the hardware notch in points (fallback for non-notch Macs).
    let notchWidth: CGFloat
    /// Height of the menu-bar / notch area in points.
    let notchHeight: CGFloat

    init(screen: NSScreen) {
        self.screen = screen

        // On notched displays the top-left and top-right auxiliary areas flank
        // the notch; the gap between them is the notch width.
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            self.notchWidth = right.minX - left.maxX
            self.notchHeight = max(left.height, right.height)
        } else {
            // No notch (external display / older Mac): synthesize a pill.
            self.notchWidth = 200
            self.notchHeight = max(24, screen.safeAreaInsets.top)
        }
    }

    static var primary: NotchMetrics {
        NotchMetrics(screen: NSScreen.main ?? NSScreen.screens[0])
    }
}

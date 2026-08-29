import SwiftUI

/// The panel's root. Paints the black pill (square top, rounded bottom) in
/// SwiftUI so it stays opaque, then draws the content and the accent tray on
/// top. Swaps between the collapsed timer pill and the expanded dashboard.
struct RootNotchView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var focus: FocusTimer
    @EnvironmentObject private var store: Store

    /// Bottom-corner radius: roomy when expanded, tight when collapsed (a large
    /// radius on the short pill would swallow the tray's side segments).
    private var pillCorner: CGFloat { vm.expanded ? Theme.notchCorner : 12 }

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape(bottomRadius: pillCorner).fill(Color.black)
            content
            trayOverlay
        }
        // Fill whatever size the NSWindow animates to — the window owns the
        // frame animation; the view must NOT animate its own size too.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(NotchShape(bottomRadius: pillCorner))
        .contentShape(Rectangle())
        .onHover { hovering in vm.hover(hovering) }
    }

    @ViewBuilder private var content: some View {
        if vm.expanded {
            NotchDashboardView()
                .transition(.opacity)
        } else {
            CollapsedTimerView()
                .transition(.opacity)
        }
    }

    /// The accent tray — identical treatment whether collapsed or expanded:
    /// a faint full track (visible on BOTH sides + bottom) plus a bright fill
    /// that grows with progress. Same line width in both states. Hidden only
    /// for the bare idle notch.
    private var trayLineWidth: CGFloat { 2.5 }

    @ViewBuilder private var trayOverlay: some View {
        // Collapsed pill only draws the tray when the timeline is enabled; the
        // expanded dashboard always keeps its accent border.
        if vm.expanded || (focus.isActive && store.settings.showTimeline) {
            // Collapsed: hug tightly (small insets, low corner) so the short
            // side segments still read. Expanded: roomier inset.
            //
            // The tray's bottom corner radius must stay <= pillCorner - inset, or
            // its rounded corners bulge past the pill's rounded bottom and get
            // clipped flat — reading as a "cut" border (most obvious when idle,
            // with no bright progress fill drawn over it).
            let inset: CGFloat = vm.expanded ? 7 : 6
            // Keep the tray corner strictly INSIDE the pill's clip: subtract the
            // stroke's outward reach (half the line width) plus a hairline, so
            // the rounded corner never touches the clip edge and gets shaved
            // flat. `pillCorner - inset` alone sits exactly on the boundary and
            // clips intermittently as the window lands on different subpixels.
            let corner = max(4, pillCorner - inset - trayLineWidth)
            let shape = NotchTrayShape(inset: inset,
                                       topInset: vm.expanded ? 7 : 5,
                                       corner: corner)
            let style = StrokeStyle(lineWidth: trayLineWidth, lineCap: .round)
            if store.settings.rainbowTimeline {
                // Animated RGB: the whole hue spectrum is laid out ALONG the
                // line at once (a moving multicolor gradient), not one shifting
                // solid color. `TimelineView(.animation)` re-derives the phase
                // every frame and only ticks while the view is on screen.
                TimelineView(.animation) { timeline in
                    let phase = Self.rainbowPhase(at: timeline.date)
                    trayBody(shape: shape, style: style,
                             track: Self.rainbowGradient(phase: phase, opacity: 0.25),
                             fill: Self.rainbowGradient(phase: phase, opacity: 1),
                             glow: Color(hue: phase, saturation: 0.9, brightness: 1))
                }
            } else {
                trayBody(shape: shape, style: style,
                         track: Theme.accent.opacity(0.5),
                         fill: Theme.accent, glow: nil)
            }
        }
    }

    /// One tray: faint full track + bright progress fill, optionally glowing.
    /// Generic over the stroke style so it works for both a solid `Color` and
    /// the animated rainbow `LinearGradient`.
    private func trayBody<S: ShapeStyle>(shape: NotchTrayShape, style: StrokeStyle,
                                         track: S, fill: S, glow: Color?) -> some View {
        ZStack {
            // Full track, both sides + bottom, always visible.
            shape.stroke(track, style: style)
            // Bright progress fill (0 when no timer is running). Animate over
            // a full second so it flows continuously instead of ticking.
            shape.trim(from: 0, to: focus.isActive ? focus.progress : 0)
                .stroke(fill, style: style)
                .animation(.linear(duration: 1.0), value: focus.progress)
        }
        .shadow(color: glow ?? .clear, radius: glow == nil ? 0 : 6)
    }

    /// Phase in 0..<1 that advances a full turn every `period` seconds; drives
    /// the gradient's motion. Derived purely from the clock so it stays smooth.
    private static func rainbowPhase(at date: Date, period: Double = 4) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
    }

    /// The full hue spectrum spread across the line, rotated by `phase` so the
    /// colors flow. Opacity is baked into the stops so the faint track and the
    /// bright fill can share one builder.
    private static func rainbowGradient(phase: Double, opacity: Double) -> LinearGradient {
        let stops = stride(from: 0.0, through: 1.0, by: 0.1).map { p -> Gradient.Stop in
            let hue = (p + phase).truncatingRemainder(dividingBy: 1)
            return .init(color: Color(hue: hue, saturation: 0.9, brightness: 1).opacity(opacity),
                         location: p)
        }
        return LinearGradient(gradient: Gradient(stops: stops),
                              startPoint: .leading, endPoint: .trailing)
    }
}

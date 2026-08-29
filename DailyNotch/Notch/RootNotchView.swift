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
            let shape = NotchTrayShape(inset: inset,
                                       topInset: vm.expanded ? 7 : 5,
                                       corner: max(4, pillCorner - inset))
            let style = StrokeStyle(lineWidth: trayLineWidth, lineCap: .round)
            ZStack {
                // Full track, both sides + bottom, always visible.
                shape.stroke(Theme.accent.opacity(0.5), style: style)
                // Bright progress fill (0 when no timer is running). Animate over
                // a full second so it flows continuously instead of ticking.
                shape.trim(from: 0, to: focus.isActive ? focus.progress : 0)
                    .stroke(Theme.accent, style: style)
                    .animation(.linear(duration: 1.0), value: focus.progress)
            }
        }
    }
}

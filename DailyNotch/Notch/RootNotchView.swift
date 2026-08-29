import SwiftUI

/// The panel's root. The black rounded backing is provided by the window's
/// CALayer (see NotchWindowController) so we only draw content + the accent
/// tray here. Swaps between the collapsed timer pill and the expanded dashboard.
struct RootNotchView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var focus: FocusTimer

    var body: some View {
        ZStack(alignment: .top) {
            content
            trayOverlay
        }
        // Fill whatever size the NSWindow animates to — the window owns the
        // frame animation; the view must NOT animate its own size too.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        if vm.expanded || focus.isActive {
            let shape = NotchTrayShape(inset: 7,
                                       topInset: vm.expanded ? 7 : 8,
                                       corner: vm.expanded ? 20 : 13)
            let style = StrokeStyle(lineWidth: trayLineWidth, lineCap: .round)
            ZStack {
                // Full track, both sides + bottom, always visible.
                shape.stroke(Theme.accent.opacity(0.45), style: style)
                // Bright progress fill (0 when no timer is running). Animate over
                // a full second so it flows continuously instead of ticking.
                shape.trim(from: 0, to: focus.isActive ? focus.progress : 0)
                    .stroke(Theme.accent, style: style)
                    .animation(.linear(duration: 1.0), value: focus.progress)
            }
        }
    }
}

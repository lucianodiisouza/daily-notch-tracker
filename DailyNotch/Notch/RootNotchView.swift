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

    /// The accent tray: a static inset frame when expanded, a live progress
    /// track when a timer is running. Never shown for the bare idle notch.
    @ViewBuilder private var trayOverlay: some View {
        if vm.expanded {
            NotchTrayShape(inset: 7, topInset: 7, corner: 20)
                .stroke(Theme.accent, style: .init(lineWidth: 2, lineCap: .round))
        } else if focus.isActive {
            let shape = NotchTrayShape(inset: 6, topInset: 6, corner: 15)
            ZStack {
                shape.stroke(Theme.accent.opacity(0.28),
                             style: .init(lineWidth: 3, lineCap: .round))
                shape.trim(from: 0, to: focus.progress)
                    .stroke(Theme.accent, style: .init(lineWidth: 3, lineCap: .round))
                    .animation(.linear(duration: 0.3), value: focus.progress)
            }
        }
    }
}

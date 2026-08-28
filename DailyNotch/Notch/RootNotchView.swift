import SwiftUI

/// The panel's root. Renders the black notch shape and swaps between the
/// collapsed timer pill and the expanded dashboard on hover.
struct RootNotchView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var focus: FocusTimer

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape()
                .fill(Theme.pill)
                .overlay(
                    NotchShape()
                        .stroke(Theme.accent.opacity(vm.expanded ? 0.9 : 0), lineWidth: 1.5)
                )

            Group {
                if vm.expanded {
                    NotchDashboardView()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    CollapsedTimerView()
                        .transition(.opacity)
                }
            }
        }
        // Fill whatever size the NSWindow animates to — the window owns the
        // frame animation; the view must NOT animate its own size too, or the
        // two animations fight and the notch flickers.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(NotchShape())
        .onHover { hovering in vm.hover(hovering) }
    }
}

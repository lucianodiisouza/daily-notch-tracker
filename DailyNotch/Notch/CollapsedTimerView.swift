import SwiftUI

/// Collapsed pill. When a focus session is running it shows the countdown in
/// the LEFT ear and the active task in the RIGHT ear, with a hard center gap
/// the exact width of the hardware notch so nothing hides under the camera.
/// When idle it's just the bare notch footprint (invisible).
struct CollapsedTimerView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var focus: FocusTimer

    var body: some View {
        if focus.isActive {
            VStack(spacing: 0) {
                // ---- ears (aligned to the notch height) ----
                HStack(spacing: 0) {
                    // left ear: countdown, pushed toward the notch
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        Text(focus.timeLabel)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .monospacedDigit()
                    }
                    .frame(width: vm.activeEarWidth, alignment: .trailing)
                    .padding(.trailing, 12)

                    // center: the physical notch — must stay empty
                    Color.clear.frame(width: vm.notchWidth)

                    // right ear: active task title
                    HStack(spacing: 6) {
                        Text(focus.activeTask?.title ?? "")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.accent)
                    }
                    .frame(width: vm.activeEarWidth, alignment: .leading)
                    .padding(.leading, 12)
                }
                .frame(height: vm.notchHeight)

                // Progress lives in the accent tray (drawn in RootNotchView);
                // this spacer just reserves the room below the notch line.
                Spacer(minLength: 0)
            }
        } else {
            Color.clear
        }
    }
}

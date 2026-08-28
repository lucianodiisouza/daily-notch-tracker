import SwiftUI

/// Collapsed pill: countdown on the left, active task on the right, blue
/// progress bar hugging the bottom edge. When idle it's just the bare notch.
struct CollapsedTimerView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var focus: FocusTimer

    var body: some View {
        VStack(spacing: 0) {
            if focus.isActive {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                    Text(focus.timeLabel)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()

                    Spacer(minLength: 8)

                    Text(focus.activeTask?.title ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.accent)
                }
                .padding(.horizontal, 14)
                .frame(maxHeight: .infinity)

                // progress bar along the bottom
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(Theme.accent)
                            .frame(width: max(4, geo.size.width * focus.progress))
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)
            } else {
                Color.clear   // bare notch when nothing is running
            }
        }
    }
}

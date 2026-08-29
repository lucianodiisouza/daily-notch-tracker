import SwiftUI

/// Focus-time editor styled like the macOS Clock app's timer: a button
/// shows the current value, tapping it opens a popover with a large
/// number, +/- buttons, and a row of preset chips. Two-way binding.
struct FocusTimePicker: View {
    @Binding var minutes: Int
    let range: ClosedRange<Int>
    let presets: [Int]
    @State private var popoverShown = false

    var body: some View {
        Button {
            popoverShown.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
                Text("\(minutes)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color.white.opacity(0.06), in: Capsule())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $popoverShown, arrowEdge: .leading) {
            popoverContent
        }
    }

    private var popoverContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                stepperButton(systemImage: "minus", delta: -1)
                Spacer()
                VStack(spacing: -2) {
                    Text("\(minutes)")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text("min")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .textCase(.uppercase)
                }
                Spacer()
                stepperButton(systemImage: "plus", delta: 1)
            }

            HStack(spacing: 5) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        minutes = preset
                    } label: {
                        Text("\(preset)")
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(preset == minutes ? Theme.accent : Theme.panel,
                                        in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(preset == minutes ? .white : Theme.textSecondary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(width: 270)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    private func stepperButton(systemImage: String, delta: Int) -> some View {
        Button { adjust(delta) } label: {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 28, height: 28)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func adjust(_ delta: Int) {
        // Fine-grained 1-min steps so the user can land on any value; presets
        // cover the common Pomodoro durations without forcing a 5-min grid.
        let raw = minutes + delta
        minutes = max(range.lowerBound, min(range.upperBound, raw))
    }
}

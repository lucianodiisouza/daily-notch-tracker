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
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                Text("\(minutes) min")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $popoverShown, arrowEdge: .leading) {
            popoverContent
        }
    }

    private var popoverContent: some View {
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                stepperButton(systemImage: "minus", delta: -5)
                Spacer()
                VStack(spacing: -2) {
                    Text("\(minutes)")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text("min")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .textCase(.uppercase)
                }
                Spacer()
                stepperButton(systemImage: "plus", delta: 5)
            }

            HStack(spacing: 6) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        minutes = preset
                    } label: {
                        Text("\(preset)")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(preset == minutes ? Theme.accent : Theme.panel,
                                        in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(preset == minutes ? .white : Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(width: 240)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    private func stepperButton(systemImage: String, delta: Int) -> some View {
        Button { adjust(delta) } label: {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 32, height: 32)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func adjust(_ delta: Int) {
        let step = 5
        let raw = minutes + (delta > 0 ? step : -step)
        minutes = max(range.lowerBound, min(range.upperBound, raw))
    }
}

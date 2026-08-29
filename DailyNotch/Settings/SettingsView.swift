import SwiftUI

/// Editable view of `FocusSettings`. Two-way bindings write back to the store
/// on every change, so the next focus block picks up the new durations.
struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Settings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("TIMER")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                stepper("Focus",
                        value: $store.settings.focusMinutes,
                        range: FocusSettings.focusRange,
                        unit: { $0 == 1 ? "min" : "min" })
                stepper("Break",
                        value: $store.settings.breakMinutes,
                        range: FocusSettings.breakRange,
                        unit: { _ in "min" })
            }
            .padding(14)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 10) {
                Text("ALERTS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Toggle(isOn: $store.settings.notificationsEnabled) {
                    Text("Notification when a focus block ends")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textPrimary)
                }
                .toggleStyle(.switch)
                Toggle(isOn: $store.settings.playSound) {
                    Text("Play sound when a focus block ends")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textPrimary)
                }
                .toggleStyle(.switch)
            }
            .padding(14)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 420, height: 340)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    private func stepper(_ label: String,
                         value: Binding<Int>,
                         range: ClosedRange<Int>,
                         unit: (Int) -> String) -> some View {
        Stepper(value: value, in: range, step: 5) {
            HStack {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(value.wrappedValue) \(unit(value.wrappedValue))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

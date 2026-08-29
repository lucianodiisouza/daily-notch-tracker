import SwiftUI

/// Editable view of `FocusSettings`. Two-way bindings write back to the store
/// on every change, so the next focus block picks up the new durations.
///
/// The two sections (TIMER and ALERTS) share the same row shape: label on
/// the left, control on the right, so the eye reads them as one continuous
/// list instead of two visually different blocks.
struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @StateObject private var launchAtLogin = LaunchAtLoginController()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            section("TIMER") {
                timerRow("Focus", minutes: $store.settings.focusMinutes,
                         range: FocusSettings.focusRange,
                         presets: [15, 25, 30, 45, 60, 90])
                divider
                timerRow("Short break", minutes: $store.settings.breakMinutes,
                         range: FocusSettings.breakRange,
                         presets: [1, 5, 10, 15, 30])
                divider
                timerRow("Long break", minutes: $store.settings.longBreakMinutes,
                         range: FocusSettings.longBreakRange,
                         presets: [10, 15, 20, 30, 45])
            }
            section("ALERTS") {
                toggleRow("Notification when a focus block ends",
                          isOn: $store.settings.notificationsEnabled)
                divider
                toggleRow("Play sound when a focus block ends",
                          isOn: $store.settings.playSound)
            }
            section("STARTUP") {
                toggleRow("Launch DailyNotch at login",
                          isOn: Binding(
                            get: { launchAtLogin.isEnabled },
                            set: { new in _Concurrency.Task { await launchAtLogin.setEnabled(new) } }
                          ))
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 420)
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    // MARK: - Building blocks

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }

    @ViewBuilder
    private func section<C: View>(_ title: String,
                                  @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private func timerRow(_ label: String, minutes: Binding<Int>,
                          range: ClosedRange<Int>, presets: [Int]) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            FocusTimePicker(
                minutes: minutes, range: range, presets: presets
            )
            .frame(width: 130)
        }
    }
}

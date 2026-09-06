import SwiftUI
import AppKit

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
    /// Ticks every time macOS reports a display configuration change so the
    /// Picker re-reads `NSScreen.screens` (which is not a SwiftUI-observed
    /// value) and re-renders the per-screen entries + disabled state.
    @State private var displayConfigurationTick: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            section("TIMER") {
                timerRow("Focus", minutes: $store.settings.focusMinutes,
                         range: FocusSettings.focusRange,
                         presets: [15, 25, 30, 45, 60, 90])
            }
            section("ALERTS") {
                toggleRow("Notification when a focus block ends",
                          isOn: $store.settings.notificationsEnabled)
                divider
                toggleRow("Play sound when a focus block ends",
                          isOn: $store.settings.playSound)
            }
            section("APPEARANCE") {
                toggleRow("Show progress timeline on the notch",
                          isOn: $store.settings.showTimeline)
                divider
                toggleRow("RGB glow timeline (override accent color)",
                          isOn: $store.settings.rainbowTimeline)
                divider
                toggleRow("Minimal mode (hide time + task name)",
                          isOn: $store.settings.minimalMode)
            }
            section("DISPLAY") {
                displayRow()
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
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification
        )) { _ in
            displayConfigurationTick &+= 1
        }
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

    /// Picker row for the display preference. Reading `displayConfigurationTick`
    /// inside the body forces a re-render whenever the screen configuration
    /// changes, so the per-screen list stays in sync with hot-plug events.
    private func displayRow() -> some View {
        // Touch the tick so SwiftUI tracks the dependency on the State value.
        let tick = displayConfigurationTick
        let screens = NSScreen.screens
        let externalCount = screens.filter { !$0.isBuiltIn }.count
        let builtInCount = screens.filter { $0.isBuiltIn }.count
        let savedPreference = store.settings.displayPreference

        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Show the notch on")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                Text(displaySubtitle(screenCount: screens.count))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 12)
            Picker("", selection: $store.settings.displayPreference) {
                Text("Automatic").tag(DisplayPreference.auto)
                Text("MacBook's built-in")
                    .tag(DisplayPreference.builtIn)
                    .disabled(builtInCount == 0)
                Text("External monitor")
                    .tag(DisplayPreference.external)
                    .disabled(externalCount == 0)
                if !screens.isEmpty {
                    Divider()
                    ForEach(Array(screens.enumerated()), id: \.offset) { _, screen in
                        if let id = screen.displayID {
                            Text(screenLabel(for: screen))
                                .tag(DisplayPreference.specific(id))
                        }
                    }
                }
                // If a previously-saved .specific ID is no longer connected,
                // surface it as a non-selectable footnote so the user can see
                // what was selected and pick a replacement.
                if case .specific(let savedID) = savedPreference,
                   !screens.contains(where: { $0.displayID == savedID }) {
                    Divider()
                    Text("Saved display offline (ID \(savedID))")
                        .foregroundStyle(Theme.textSecondary)
                        .disabled(true)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 200)
            // Referencing `tick` here makes the dependency explicit and
            // silences "never used" warnings; the real tracking already
            // happened in the closure passed to onReceive.
            .onAppear { _ = tick }
        }
    }

    private func displaySubtitle(screenCount: Int) -> String {
        switch screenCount {
        case 0: return "No displays detected"
        case 1: return "1 display connected"
        default: return "\(screenCount) displays connected"
        }
    }

    private func screenLabel(for screen: NSScreen) -> String {
        let resolution = "\(Int(screen.frame.width))×\(Int(screen.frame.height))"
        let kind = screen.isBuiltIn ? "Built-in" : "External"
        return "\(screen.displayName) — \(resolution) (\(kind))"
    }
}

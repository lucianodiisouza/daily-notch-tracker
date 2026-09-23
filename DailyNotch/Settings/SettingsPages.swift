import AppKit
import SwiftUI
import UserNotifications

// One view per page of the settings window. Every control writes straight into `store.settings`, which saves itself
// on every change.

// MARK: - Focus

struct FocusSettingsPage: View {
    @EnvironmentObject private var store: Store

    private static let presets = [15, 25, 45, 60, 90]

    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "Focus", subtitle: "How long a focus block runs")
            SettingsGroup(footer: "Each task can have its own length. This one is the default for new tasks, and for ⌘⇧Space when the day has no tasks.") {
                SettingsSliderRow(
                    symbol: "timer", color: SettingsPageID.focus.color, title: "Focus length",
                    value: Binding(
                        get: { Double(store.settings.focusMinutes) },
                        set: { store.settings.focusMinutes = Int($0) }),
                    range: 5...180, step: 5,
                    format: { String(localized: "\(Int($0)) min") })
                SettingsRow(symbol: "sparkles", color: Color(hex: "#F59E0B"), title: "Quick picks") {
                    HStack(spacing: 6) {
                        ForEach(Self.presets, id: \.self) { minutes in
                            PresetChip(minutes: minutes, isSelected: store.settings.focusMinutes == minutes) {
                                store.settings.focusMinutes = minutes
                            }
                        }
                    }
                }
            }
            SettingsGroup(title: "Today's progress") {
                SettingsRow(symbol: "clock.fill", color: Color(hex: "#0EA5E9"), title: "Focused today") {
                    StatText(Self.duration(store.focusedSecondsToday))
                }
                SettingsRow(symbol: "checkmark.circle.fill", color: Color(hex: "#22C55E"), title: "Blocks completed today") {
                    StatText("\(store.completedBlocksToday)")
                }
                SettingsRow(symbol: "flame.fill", color: Color(hex: "#EF4444"), title: "Current streak",
                            subtitle: "Days in a row with at least one focus block") {
                    StatText(String(localized: "\(store.currentStreak) days"))
                }
            }
        }
    }

    private static func duration(_ seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: TimeInterval(seconds)) ?? "0m"
    }
}

private struct StatText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }
}

private struct PresetChip: View {
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(minutes)")
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(minWidth: 34, minHeight: 24)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notch

struct NotchSettingsPage: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "Notch", subtitle: "What the notch shows while a focus block runs")
            HStack(spacing: 14) {
                VisualChoiceCard(title: "Standard", isSelected: !store.settings.minimalMode) {
                    store.settings.minimalMode = false
                } preview: {
                    NotchPreview(minimal: false, settings: store.settings)
                }
                VisualChoiceCard(title: "Minimal", isSelected: store.settings.minimalMode) {
                    store.settings.minimalMode = true
                } preview: {
                    NotchPreview(minimal: true, settings: store.settings)
                }
            }
            Text(store.settings.minimalMode
                 ? "Minimal hides the countdown and the task name. Only the progress line shows."
                 : "Standard shows the countdown on the left of the notch and the task on the right.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            SettingsGroup {
                SettingsToggleRow(
                    symbol: "chart.line.flattrend.xyaxis", color: SettingsPageID.notch.color,
                    title: "Progress timeline",
                    subtitle: "A line around the notch fills up as the block runs",
                    isOn: $store.settings.showTimeline)
                SettingsToggleRow(
                    symbol: "rainbow", color: Color(hex: "#EC4899"),
                    title: "RGB timeline",
                    subtitle: "Animated rainbow with a soft glow instead of your accent color",
                    isOn: $store.settings.rainbowTimeline)
                    .disabled(!store.settings.showTimeline)
            }
        }
    }
}

/// A small desktop with a menu bar and the notch hanging from its middle, drawn the way the real pill looks
/// mid-focus.
private struct NotchPreview: View {
    let minimal: Bool
    let settings: FocusSettings

    private let barHeight: CGFloat = 22
    private let notchWidth: CGFloat = 70
    private let earWidth: CGFloat = 62
    private let progress: CGFloat = 0.62

    var body: some View {
        let width = minimal ? notchWidth + 20 : notchWidth + earWidth * 2
        let height = settings.showTimeline ? barHeight + (minimal ? 7 : 11) : barHeight
        ZStack(alignment: .top) {
            menuBar
            ZStack(alignment: .top) {
                ZStack(alignment: .top) {
                    NotchShape(bottomRadius: 10).fill(Color.black)
                    if !minimal {
                        HStack(spacing: 0) {
                            HStack(spacing: 3) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))
                                Text(verbatim: "18:42")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 6)
                            Color.clear.frame(width: notchWidth)
                            Text("Write report")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 6)
                        }
                        .frame(height: barHeight)
                    }
                }
                .clipShape(NotchShape(bottomRadius: 10))
                if settings.showTimeline {
                    timeline
                }
            }
            .frame(width: width, height: height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Translucent strip with blurred-out menus on the left and status icons on the right.
    private var menuBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "apple.logo").font(.system(size: 9))
            ForEach([26, 20, 24], id: \.self) { w in
                Capsule().frame(width: CGFloat(w), height: 4)
            }
            Spacer()
            ForEach(0..<3, id: \.self) { _ in
                Circle().frame(width: 5, height: 5)
            }
            Capsule().frame(width: 22, height: 4)
        }
        .foregroundStyle(.white.opacity(0.55))
        .padding(.horizontal, 12)
        .frame(height: barHeight)
        .background(Color.white.opacity(0.12))
    }

    @ViewBuilder
    private var timeline: some View {
        let shape = NotchTrayShape(inset: 3.5, topInset: 3, corner: 6)
        let style = StrokeStyle(lineWidth: 1.8, lineCap: .round)
        if settings.rainbowTimeline {
            let rainbow = LinearGradient(
                colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple],
                startPoint: .leading, endPoint: .trailing)
            ZStack {
                shape.stroke(rainbow.opacity(0.3), style: style)
                shape.trim(from: 0, to: progress).stroke(rainbow, style: style)
            }
            .shadow(color: .pink.opacity(0.8), radius: 3)
        } else {
            ZStack {
                shape.stroke(Theme.accent.opacity(0.5), style: style)
                shape.trim(from: 0, to: progress).stroke(Theme.accent, style: style)
            }
        }
    }
}

// MARK: - Display

struct DisplaySettingsPage: View {
    @EnvironmentObject private var store: Store
    /// Bumped when displays come and go, so the lists re-read `NSScreen.screens`, which SwiftUI does not observe.
    @State private var screensChanged = 0

    var body: some View {
        let _ = screensChanged
        let screens = NSScreen.screens
        let hasBuiltIn = screens.contains { $0.isBuiltIn }
        let hasExternal = screens.contains { !$0.isBuiltIn }
        let active = DisplayResolver.resolve(store.settings.displayPreference,
                                             fallback: NSScreen.main ?? screens[0])

        SettingsPage {
            SettingsSectionTitle(title: "Display", subtitle: "Which screen the notch appears on")
            SettingsGroup(footer: "Screens without a notch get a small pill at the top center instead.") {
                SettingsPickerRow(
                    symbol: "display", color: SettingsPageID.display.color, title: "Show the notch on",
                    subtitle: "Automatic follows the screen with the active menu bar",
                    selection: $store.settings.displayPreference
                ) {
                    Text("Automatic").tag(DisplayPreference.auto)
                    Text("MacBook's built-in display").tag(DisplayPreference.builtIn)
                        .disabled(!hasBuiltIn)
                    Text("External display").tag(DisplayPreference.external)
                        .disabled(!hasExternal)
                    Divider()
                    ForEach(screens, id: \.self) { screen in
                        if let id = screen.displayID {
                            Text(screen.displayName).tag(DisplayPreference.specific(id))
                        }
                    }
                    if case .specific(let saved) = store.settings.displayPreference,
                       !screens.contains(where: { $0.displayID == saved }) {
                        Text("Saved display (not connected)").tag(DisplayPreference.specific(saved))
                    }
                }
            }
            SettingsGroup(title: "Connected displays") {
                ForEach(screens, id: \.self) { screen in
                    SettingsRow(
                        symbol: screen.isBuiltIn ? "laptopcomputer" : "display",
                        color: screen.isBuiltIn ? Color(hex: "#64748B") : SettingsPageID.display.color,
                        title: screen.displayName,
                        subtitle: Self.details(for: screen)
                    ) {
                        if screen == active {
                            Label("Notch here", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screensChanged &+= 1
        }
    }

    private static func details(for screen: NSScreen) -> String {
        let size = "\(Int(screen.frame.width)) × \(Int(screen.frame.height))"
        let kind = screen.isBuiltIn ? String(localized: "Built-in") : String(localized: "External")
        let notch = screen.auxiliaryTopLeftArea != nil ? String(localized: "with notch") : String(localized: "no notch")
        return "\(size) · \(kind) · \(notch)"
    }
}

// MARK: - Alerts

struct AlertsSettingsPage: View {
    @EnvironmentObject private var store: Store
    /// nil until asked, false when macOS blocks DailyNotch's notifications.
    @State private var notificationsAllowed: Bool? = true

    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "Alerts", subtitle: "What happens when a focus block ends")
            SettingsGroup {
                SettingsToggleRow(
                    symbol: "bell.badge.fill", color: SettingsPageID.alerts.color, title: "Notification",
                    subtitle: "A notification with the name of the task you finished",
                    isOn: Binding(
                        get: { store.settings.notificationsEnabled },
                        set: {
                            store.settings.notificationsEnabled = $0
                            if $0 { askForNotifications() }
                        }))
                SettingsRow(
                    symbol: "speaker.wave.2.fill", color: Color(hex: "#F59E0B"), title: "Sound",
                    subtitle: "A soft chime, even when notifications are off"
                ) {
                    HStack(spacing: 10) {
                        Button("Play") { NSSound(named: "Glass")?.play() }
                        Toggle("", isOn: $store.settings.playSound)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            }
            if store.settings.notificationsEnabled && notificationsAllowed == false {
                SettingsGroup {
                    SettingsRow(
                        symbol: "bell.slash.fill", color: Color(hex: "#6B7280"), title: "Notifications are off",
                        subtitle: "macOS is blocking notifications from DailyNotch"
                    ) {
                        Button("Open System Settings…") {
                            let id = Bundle.main.bundleIdentifier ?? ""
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }
        }
        .task { await refreshPermission() }
        // Back from System Settings with the switch flipped.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            _Concurrency.Task { await refreshPermission() }
        }
    }

    private func askForNotifications() {
        NotificationService.shared.requestAuthorizationIfNeeded()
        _Concurrency.Task {
            try? await _Concurrency.Task.sleep(for: .seconds(1))
            await refreshPermission()
        }
    }

    private func refreshPermission() async {
        notificationsAllowed = await NotificationService.shared.isAuthorized()
    }
}

// MARK: - Calendar

struct CalendarSettingsPage: View {
    @StateObject private var calendar = CalendarAuthModel()

    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "Calendar", subtitle: "Your events next to your tasks")
            SettingsGroup(footer: "DailyNotch only reads your events to list them under the day's tasks in the Tasks window. It never changes them, and they never leave your Mac.") {
                SettingsRow(
                    symbol: "calendar", color: SettingsPageID.calendar.color, title: "Calendar access",
                    subtitle: status
                ) {
                    switch calendar.state {
                    case .notDetermined:
                        Button("Connect…") {
                            _Concurrency.Task { await calendar.requestAccess() }
                        }
                    case .denied, .restricted:
                        Button("Open System Settings…") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    case .authorized:
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "#22C55E"))
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            calendar.refresh(for: Date())
        }
    }

    private var status: String {
        switch calendar.state {
        case .notDetermined: return String(localized: "Not connected yet")
        case .denied: return String(localized: "Access was denied. Turn it on in System Settings.")
        case .restricted: return String(localized: "Access is restricted on this Mac")
        case .authorized:
            let count = calendar.events.count
            return String(localized: "\(count) events today")
        }
    }
}

// MARK: - General

struct GeneralSettingsPage: View {
    @EnvironmentObject private var store: Store
    @StateObject private var launchAtLogin = LaunchAtLoginController()
    @State private var confirmingRestore = false

    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "General")
            SettingsGroup(footer: launchAtLogin.error) {
                SettingsToggleRow(
                    symbol: "power", color: Color(hex: "#22C55E"), title: "Open at login",
                    subtitle: "Start DailyNotch when you log in to your Mac",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }))
            }
            SettingsGroup {
                SettingsRow(
                    symbol: "globe", color: Color(hex: "#3B82F6"), title: "Language",
                    subtitle: "DailyNotch follows your Mac's language. You can pick another one just for DailyNotch"
                ) {
                    Button("Change…") {
                        // System Settings → General → Language & Region, where the Applications list sets it per app.
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            SettingsGroup {
                SettingsRow(
                    symbol: "externaldrive.fill", color: Color(hex: "#0EA5E9"), title: "Your data",
                    subtitle: "Tasks and focus history are saved in one file on this Mac"
                ) {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.dataFileURL])
                    }
                }
                SettingsRow(
                    symbol: "arrow.counterclockwise", color: Color(hex: "#EF4444"), title: "Restore defaults",
                    subtitle: "Put every setting back the way it was on first launch. Tasks and history stay"
                ) {
                    Button("Restore…") { confirmingRestore = true }
                }
            }
        }
        .onAppear { launchAtLogin.refresh() }
        .confirmationDialog("Restore the default settings?", isPresented: $confirmingRestore) {
            Button("Restore Defaults", role: .destructive) {
                store.settings = .default
            }
        } message: {
            Text("Your tasks and focus history are not touched.")
        }
    }
}

// MARK: - Shortcuts

struct ShortcutsSettingsPage: View {
    @EnvironmentObject private var store: Store
    @ObservedObject private var menuState = FocusMenuState.shared

    var body: some View {
        SettingsPage {
            SettingsSectionTitle(title: "Shortcuts", subtitle: "Run your focus without leaving what you are doing")
            SettingsGroup(
                title: "From any app",
                footer: store.settings.globalHotkeyEnabled && !menuState.hotkeyRegistered
                    ? "Another app already uses ⌘⇧Space, so DailyNotch could not take it."
                    : "Starts the first unfinished task of the day, or a plain block when the day is empty. Press again to stop."
            ) {
                SettingsRow(
                    symbol: "play.circle.fill", color: SettingsPageID.shortcuts.color, title: "Start or stop focus",
                    subtitle: "Works while any other app is in front"
                ) {
                    HStack(spacing: 10) {
                        KeyCaps(keys: ["⌘", "⇧", "Space"])
                        Toggle("", isOn: $store.settings.globalHotkeyEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            }
            SettingsGroup(title: "Tasks window") {
                ShortcutRow(symbol: "plus.circle.fill", title: "New task", keys: ["⌘", "N"])
                ShortcutRow(symbol: "calendar", title: "Go to today", keys: ["⌘", "T"])
                ShortcutRow(symbol: "xmark.circle.fill", title: "Close window", keys: ["⌘", "W"])
            }
            SettingsGroup(title: "Menu bar", footer: "In the hourglass menu.") {
                ShortcutRow(symbol: "checklist", title: "Open Tasks", keys: ["⌘", "T"])
                ShortcutRow(symbol: "gearshape.fill", title: "Settings", keys: ["⌘", ","])
                ShortcutRow(symbol: "power", title: "Quit DailyNotch", keys: ["⌘", "Q"])
            }
        }
    }
}

private struct ShortcutRow: View {
    let symbol: String
    let title: String
    let keys: [String]

    var body: some View {
        SettingsRow(symbol: symbol, color: SettingsPageID.shortcuts.color, title: title) {
            KeyCaps(keys: keys)
        }
    }
}

private struct KeyCaps: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key.localized)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .padding(.horizontal, 7)
                    .frame(minWidth: 24, minHeight: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.12)))
                    )
            }
        }
    }
}

// MARK: - About

struct AboutSettingsPage: View {
    @ObservedObject private var updates = UpdateChecker.shared

    private static let repo = URL(string: "https://github.com/lucianodiisouza/daily-notch-tracker")!

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return String(localized: "Version \(short) (\(build))")
    }

    var body: some View {
        SettingsPage {
            VStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                Text("DailyNotch")
                    .font(.system(size: 22, weight: .bold))
                Text(version)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text("A focus timer and to-do list that live in your MacBook's notch.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)

            SettingsGroup {
                if UpdateChecker.isEnabled {
                    SettingsRow(
                        symbol: "arrow.down.circle.fill", color: Color(hex: "#22C55E"), title: "Updates",
                        subtitle: updateStatus
                    ) {
                        if let update = updates.availableUpdate {
                            Button(String(localized: "Download \(update.version)")) { updates.openReleasePage() }
                        } else {
                            Button("Check Now") { updates.checkForUpdates(force: true) }
                                .disabled(updates.isChecking)
                        }
                    }
                }
                SettingsRow(
                    symbol: "chevron.left.forwardslash.chevron.right", color: SettingsPageID.about.color,
                    title: "Source code", subtitle: "github.com/lucianodiisouza/daily-notch-tracker"
                ) {
                    Button("Open") { NSWorkspace.shared.open(Self.repo) }
                }
                SettingsRow(
                    symbol: "hand.raised.fill", color: Color(hex: "#3B82F6"), title: "Privacy",
                    subtitle: "No account, no analytics, no tracking"
                ) {
                    Button("Read Policy") {
                        NSWorkspace.shared.open(Self.repo.appendingPathComponent("blob/main/PRIVACY.md"))
                    }
                }
            }
        }
    }

    private var updateStatus: String {
        if updates.isChecking { return String(localized: "Checking…") }
        if let update = updates.availableUpdate { return String(localized: "Version \(update.version) is available") }
        if updates.lastChecked != nil { return String(localized: "You have the latest version") }
        return String(localized: "Checks GitHub for new versions")
    }
}

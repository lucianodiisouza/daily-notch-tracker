#if DEBUG
import AppKit
import SwiftUI

/// Debug-only: renders every window of the app into PNGs with demo data, for the README and the App Store
/// screenshots, then quits. Nothing is read from or written to the user's real data file.
///
///     DailyNotch.app/Contents/MacOS/DailyNotch -snapshot 1 [-AppleLanguages '(pt-BR)']
///
/// The PNGs land in the app's temporary folder (the sandbox allows nothing else); the path is printed.
@MainActor
enum Snapshots {
    static var isRequested: Bool { UserDefaults.standard.bool(forKey: "snapshot") }

    static func run() {
        let out = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("snapshots", isDirectory: true)
        try? FileManager.default.removeItem(at: out)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let store = demoStore()
        let focus = FocusTimer(store: store)

        for scheme in [ColorScheme.dark, .light] {
            for page in SettingsPageID.allCases {
                let navigation = SettingsNavigation()
                navigation.page = page
                let view = SettingsWindowView()
                    .environmentObject(store)
                    .environment(navigation)
                    .background(Color(nsColor: .windowBackgroundColor))
                render(view, size: CGSize(width: 820, height: 600), scheme: scheme,
                       to: out.appendingPathComponent("settings-\(page.rawValue)-\(scheme == .dark ? "dark" : "light").png"))
            }
        }

        render(TasksWindowView().environmentObject(store).environmentObject(focus),
               size: CGSize(width: 760, height: 480), scheme: .dark,
               to: out.appendingPathComponent("tasks.png"))

        let metrics = NotchMetrics.primary
        let vm = NotchViewModel(store: store, focus: focus, metrics: metrics)
        vm.expanded = true
        render(notch(vm), size: vm.targetSize, scheme: .dark, to: out.appendingPathComponent("notch-expanded.png"))

        if let first = store.tasks(on: Date()).first {
            focus.start(task: first)
            // Mid-block, so the countdown and the progress line both show.
            focus.debugAdvance(seconds: Double(first.estimateMinutes * 60) * 0.38)
        }
        vm.expanded = false
        render(notch(vm), size: vm.targetSize, scheme: .dark, to: out.appendingPathComponent("notch-focus.png"))
        store.settings.rainbowTimeline = true
        render(notch(vm), size: vm.targetSize, scheme: .dark, to: out.appendingPathComponent("notch-focus-rgb.png"))
        store.settings.rainbowTimeline = false
        store.settings.minimalMode = true
        render(notch(vm), size: vm.targetSize, scheme: .dark, to: out.appendingPathComponent("notch-focus-minimal.png"))

        print("SNAPSHOTS \(out.path)")
        exit(0)
    }

    private static func notch(_ vm: NotchViewModel) -> some View {
        RootNotchView()
            .environmentObject(vm)
            .environmentObject(vm.store)
            .environmentObject(vm.focus)
    }

    private static func render<V: View>(_ view: V, size: CGSize, scheme: ColorScheme, to url: URL) {
        let hosting = NSHostingView(rootView: view.environment(\.colorScheme, scheme))
        hosting.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: CGRect(x: -20000, y: -20000, width: size.width, height: size.height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = hosting
        window.orderFrontRegardless()
        // Let SwiftUI lay out and draw.
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        hosting.layoutSubtreeIfNeeded()
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        window.orderOut(nil)
    }

    // MARK: - Demo data

    private static var isPortuguese: Bool {
        Bundle.main.preferredLocalizations.first?.hasPrefix("pt") == true
    }

    private static func demoStore() -> Store {
        let file = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("snapshot-data.json")
        try? FileManager.default.removeItem(at: file)
        let store = Store(fileURL: file)
        store.settings.notificationsEnabled = false
        store.settings.playSound = false

        let pt = isPortuguese
        let today: [(String, String, Int, Bool)] = [
            (pt ? "Escrever o relatório trimestral" : "Write the quarterly report",
             pt ? "Números de receita e próximos passos" : "Revenue numbers and next steps", 45, false),
            (pt ? "Revisar pull requests" : "Review pull requests", "", 25, false),
            (pt ? "Planejar a próxima sprint" : "Plan the next sprint",
             pt ? "Priorizar o backlog com o time" : "Prioritize the backlog with the team", 30, false),
            (pt ? "Responder o feedback de design" : "Reply to design feedback", "", 15, true),
        ]
        for (title, notes, minutes, done) in today {
            store.add(title: title, notes: notes, estimate: minutes, date: Date())
            if done, let task = store.tasks.last { store.toggleDone(task) }
        }
        store.add(title: pt ? "Ler sobre SwiftUI" : "Read up on SwiftUI", estimate: 30, date: nil)

        // A believable month: most weekdays have a few blocks, the last days in a row form a streak.
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        for back in 0..<40 {
            guard let day = cal.date(byAdding: .day, value: -back, to: start) else { continue }
            let blocks = back < 6 ? [3, 4, 2, 5, 3, 4][back] : [0, 1, 2, 0, 3, 1, 4, 2, 0, 2][back % 10]
            for b in 0..<blocks {
                let begin = day.addingTimeInterval(TimeInterval(9 * 3600 + b * 3600))
                store.recordSession(FocusSession(taskId: nil, startedAt: begin,
                                                 endedAt: begin.addingTimeInterval(25 * 60), completed: true))
            }
        }
        return store
    }
}
#endif

import SwiftUI

/// The "Pomodoro" half of the Tasks window's right panel. Renders the current
/// phase (work / short break / long break), the countdown, a progress ring,
/// the cycle dots, and the start/pause/skip/stop controls.
///
/// All colors are pulled from `PomodoroEngine.color` so the phase reads in
/// its own color (orange for work, green for short break, blue for long
/// break) — intentionally different from `Theme.accent`, which is what the
/// per-task `FocusTimer` uses.
struct PomodoroView: View {
    @EnvironmentObject private var engine: PomodoroEngine
    @EnvironmentObject private var store: Store

    var body: some View {
        VStack(spacing: 18) {
            phaseHeader

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: engine.progress)
                    .stroke(engine.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: engine.progress)
                VStack(spacing: 2) {
                    Text(engine.timeLabel)
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text(engine.phase.label.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(engine.color)
                        .tracking(1.2)
                }
            }
            .frame(width: 200, height: 200)

            cycleDots

            controls
            summary

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Pieces

    private var phaseHeader: some View {
        HStack {
            Text(headerTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
        }
    }

    private var cycleDots: some View {
        HStack(spacing: 8) {
            ForEach(1...FocusSettings.sessionsPerCycle, id: \.self) { i in
                Circle()
                    .fill(fillColor(forDot: i))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            if engine.isFinished {
                bigButton(title: "Start cycle", color: Theme.pomodoroWork) {
                    engine.start()
                }
            } else if engine.state == .running {
                iconCircleButton(systemImage: "pause.fill", color: engine.color) {
                    engine.togglePause()
                }
                iconCircleButton(systemImage: "forward.fill", color: Theme.textSecondary) {
                    engine.skip()
                }
                iconCircleButton(systemImage: "stop.fill", color: Theme.danger) {
                    engine.stop()
                }
            } else {
                // idle or paused
                bigButton(title: engine.state == .paused ? "Resume" : "Start",
                          color: engine.color) {
                    engine.togglePause()
                }
                if engine.isActive {
                    iconCircleButton(systemImage: "stop.fill", color: Theme.danger) {
                        engine.stop()
                    }
                }
            }
        }
    }

    private var summary: some View {
        VStack(spacing: 4) {
            Text("Cycle \(engine.cycle) of \(FocusSettings.sessionsPerCycle)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Text(durationsLine)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Helpers

    private var headerTitle: String {
        switch engine.state {
        case .idle:     return "Ready"
        case .running:  return engine.phase.label
        case .paused:   return "Paused — \(engine.phase.label.lowercased())"
        case .finished: return "Cycle complete"
        }
    }

    private var durationsLine: String {
        let s = store.settings
        return "\(s.focusMinutes)m work · \(s.breakMinutes)m short · \(s.longBreakMinutes)m long"
    }

    private func fillColor(forDot i: Int) -> Color {
        if engine.isFinished { return Theme.pomodoroWork.opacity(0.5) }
        if i < engine.cycle { return Theme.pomodoroWork }
        if i == engine.cycle { return engine.color }
        return Color.white.opacity(0.15)
    }

    private func bigButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 22).padding(.vertical, 10)
                .background(color, in: RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func iconCircleButton(systemImage: String, color: Color,
                                  action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(color, in: Circle())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

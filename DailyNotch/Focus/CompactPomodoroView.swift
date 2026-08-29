import SwiftUI

/// Notch-sized Pomodoro panel. The full `PomodoroView` carries a 200×200
/// progress ring that doesn't fit in the notch's left column, so this is a
/// compressed version: phase label, big countdown, cycle dots, and a single
/// start/pause/stop control. Color follows the current phase, same as the
/// window's PomodoroView.
struct CompactPomodoroView: View {
    @EnvironmentObject private var engine: PomodoroEngine

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(engine.phase.label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(engine.color)
                    .tracking(0.8)
                Spacer()
                Text("Cycle \(engine.cycle)/\(FocusSettings.sessionsPerCycle)")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
            }

            Text(engine.timeLabel)
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)

            cycleDots

            controls
        }
    }

    private var cycleDots: some View {
        HStack(spacing: 6) {
            ForEach(1...FocusSettings.sessionsPerCycle, id: \.self) { i in
                Circle()
                    .fill(dotFill(i))
                    .frame(width: 6, height: 6)
            }
        }
    }

    @ViewBuilder private var controls: some View {
        switch engine.state {
        case .idle, .finished:
            Button {
                engine.start()
            } label: {
                Text(engine.state == .finished ? "Start cycle" : "Start")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Theme.pomodoroWork, in: RoundedRectangle(cornerRadius: 7))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .running, .paused:
            HStack(spacing: 6) {
                Button {
                    engine.togglePause()
                } label: {
                    Image(systemName: engine.state == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(engine.color, in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button {
                    engine.skip()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08), in: Circle())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button {
                    engine.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Theme.danger, in: Circle())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dotFill(_ i: Int) -> Color {
        if engine.isFinished { return Theme.pomodoroWork.opacity(0.5) }
        if i < engine.cycle { return Theme.pomodoroWork }
        if i == engine.cycle { return engine.color }
        return Color.white.opacity(0.15)
    }
}

import SwiftUI

/// Contribution grid of recent focus activity with graded shades. Rows are the
/// seven weekdays (Mon…Sun); columns are weeks, most recent on the right.
struct StreakHeatmap: View {
    @EnvironmentObject private var store: Store

    private let weeks = 12
    private let cell: CGFloat = 16
    private let gap: CGFloat = 4
    private let radius: CGFloat = 4

    private var cal: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2   // Monday
        return c
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Activity", systemImage: "chart.bar.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            let counts = countsByDay()
            let today = cal.startOfDay(for: Date())
            VStack(spacing: gap) {
                ForEach(0..<7, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<weeks, id: \.self) { col in
                            cellView(for: date(row: row, col: col),
                                     today: today, counts: counts)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(for day: Date, today: Date, counts: [Date: Int]) -> some View {
        let isFuture = day > today
        RoundedRectangle(cornerRadius: radius)
            .fill(isFuture ? Color.clear : color(for: counts[day] ?? 0))
            .frame(width: cell, height: cell)
    }

    /// Date at grid position (row = weekday 0=Mon, col = week, rightmost = current).
    private func date(row: Int, col: Int) -> Date {
        let today = cal.startOfDay(for: Date())
        let weekdayIndex = (cal.component(.weekday, from: today) + 5) % 7   // Mon=0…Sun=6
        let currentWeekMonday = cal.date(byAdding: .day, value: -weekdayIndex, to: today)!
        let weekMonday = cal.date(byAdding: .day, value: -(weeks - 1 - col) * 7, to: currentWeekMonday)!
        return cal.date(byAdding: .day, value: row, to: weekMonday)!
    }

    /// Map a day's focus-session count to one of five graded shades.
    private func color(for count: Int) -> Color {
        switch count {
        case 0:  return Theme.streakEmpty
        case 1:  return Theme.accent.opacity(0.38)
        case 2:  return Theme.accent.opacity(0.60)
        case 3:  return Theme.accent.opacity(0.82)
        default: return Theme.accent
        }
    }

    private func countsByDay() -> [Date: Int] {
        var map: [Date: Int] = [:]
        for session in store.sessions {
            map[cal.startOfDay(for: session.startedAt), default: 0] += 1
        }
        return map
    }
}

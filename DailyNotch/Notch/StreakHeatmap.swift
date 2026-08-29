import SwiftUI

/// Focus-activity grid for the CURRENT month only, laid out as calendar weeks
/// (Mon…Sun columns, one row per week) under an "Activity" header. No day/month
/// axis labels — just graded cells, shaded by how many focus sessions landed on
/// each day. Days outside the month or in the future are left blank.
struct StreakHeatmap: View {
    @EnvironmentObject private var store: Store

    static let cell: CGFloat = 24
    static let gap: CGFloat = 6
    private var cell: CGFloat { Self.cell }
    private var gap: CGFloat { Self.gap }
    private let radius: CGFloat = 5

    /// Only draw the weeks up to and including today's — trailing weeks of the
    /// month sit in the future and would render as a fully-blank row, leaving
    /// dead space at the bottom of the panel.
    private var rows: Int { Self.weekRows(for: Date()) }

    private static var cal: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2   // Monday
        return c
    }
    private var cal: Calendar { Self.cal }

    /// Number of Monday-first week-rows needed to show the current month from
    /// its 1st through `date` (today). Shared with the panel's height calc.
    static func weekRows(for date: Date) -> Int {
        let today = cal.startOfDay(for: date)
        let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: today))!
        let leading = (cal.component(.weekday, from: firstOfMonth) + 5) % 7
        let dayIndex = cal.dateComponents([.day], from: firstOfMonth, to: today).day ?? 0
        return (leading + dayIndex) / 7 + 1
    }

    /// Pixel height of an `n`-row grid including inter-row gaps.
    static func gridHeight(rows n: Int) -> CGFloat {
        CGFloat(n) * cell + CGFloat(max(0, n - 1)) * gap
    }

    var body: some View {
        let counts = countsByDay()
        let today = cal.startOfDay(for: Date())
        VStack(alignment: .leading, spacing: 10) {
            Label("Activity", systemImage: "chart.bar.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { col in
                            cellView(for: date(row: row, col: col),
                                     today: today, counts: counts)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(for day: Date?, today: Date, counts: [Date: Int]) -> some View {
        // Blank slot when the cell falls outside the current month or in the future.
        let show = day.map { $0 <= today } ?? false
        RoundedRectangle(cornerRadius: radius)
            .fill(show ? color(for: counts[day!] ?? 0) : Color.clear)
            .frame(width: cell, height: cell)
    }

    /// Date at grid position within the current month, or nil for a padding slot
    /// before the 1st / after the last day.
    private func date(row: Int, col: Int) -> Date? {
        let today = cal.startOfDay(for: Date())
        let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: today))!
        // Weekday offset of the 1st within a Monday-first week (Mon=0…Sun=6).
        let leading = (cal.component(.weekday, from: firstOfMonth) + 5) % 7
        let dayIndex = row * 7 + col - leading      // 0-based day of month
        guard dayIndex >= 0,
              let candidate = cal.date(byAdding: .day, value: dayIndex, to: firstOfMonth),
              cal.isDate(candidate, equalTo: today, toGranularity: .month) else { return nil }
        return candidate
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

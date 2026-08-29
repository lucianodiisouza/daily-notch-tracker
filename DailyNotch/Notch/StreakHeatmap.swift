import SwiftUI

/// GitHub-style contribution grid of recent focus activity, with graded shades
/// per day. Dimensions match the prototype: 13 columns x 4 rows of rounded
/// cells, most-recent day in the bottom-right.
struct StreakHeatmap: View {
    @EnvironmentObject private var store: Store

    // Prototype dimensions.
    private let columns = 13
    private let rows = 4
    private let cell: CGFloat = 14
    private let gap: CGFloat = 4
    private let radius: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Journey Streak", systemImage: "flame.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(store.currentStreak)d")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            let counts = countsByDay()
            let grid = Array(repeating: GridItem(.fixed(cell), spacing: gap), count: columns)
            LazyVGrid(columns: grid, alignment: .leading, spacing: gap) {
                ForEach(gridDays, id: \.self) { day in
                    RoundedRectangle(cornerRadius: radius)
                        .fill(color(for: counts[day] ?? 0))
                        .frame(width: cell, height: cell)
                }
            }
        }
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

    /// Number of focus sessions started on each day.
    private func countsByDay() -> [Date: Int] {
        let cal = Calendar.current
        var map: [Date: Int] = [:]
        for session in store.sessions {
            let day = cal.startOfDay(for: session.startedAt)
            map[day, default: 0] += 1
        }
        return map
    }

    /// The last (rows x columns) days ending today in the bottom-right cell.
    private var gridDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let total = rows * columns
        return (0..<total).reversed().compactMap {
            cal.date(byAdding: .day, value: -$0, to: today)
        }
    }
}

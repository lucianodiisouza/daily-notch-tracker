import SwiftUI

/// GitHub-style contribution grid of the last N weeks of focus activity.
struct StreakHeatmap: View {
    @EnvironmentObject private var store: Store

    private let weeks = 13
    private let rows = 4          // compact: 4 rows shown in the notch
    private let cell: CGFloat = 12
    private let gap: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Journey Streak", systemImage: "flame.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(store.currentStreak)d")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            let active = store.activeDays
            let days = gridDays
            let columns = Array(repeating: GridItem(.fixed(cell), spacing: gap), count: weeks)
            LazyVGrid(columns: columns, alignment: .leading, spacing: gap) {
                ForEach(days, id: \.self) { day in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(active.contains(day) ? Theme.accent : Theme.streakEmpty)
                        .frame(width: cell, height: cell)
                }
            }
        }
    }

    /// Column-major days so each column is a week, matching the mockup layout.
    private var gridDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var result: [Date] = []
        // rows × weeks cells, ending today in the bottom-right
        let total = rows * weeks
        for i in stride(from: total - 1, through: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: today) {
                result.append(d)
            }
        }
        return result
    }
}

import SwiftUI

/// Simple month grid with prev/next navigation; taps select a day.
struct CalendarView: View {
    @Binding var selectedDate: Date
    @State private var visibleMonth: Date = Date()

    private let cal = Calendar.current
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                navButton("chevron.left") { shiftMonth(-1) }
                Spacer()
                Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                navButton("chevron.right") { shiftMonth(1) }
            }

            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, d in
                    Text(d)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(monthCells, id: \.self) { day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 30)
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
        let isToday = cal.isDateInToday(day)
        return Button {
            selectedDate = day
        } label: {
            Text("\(cal.component(.day, from: day))")
                .font(.system(size: 12, weight: isToday ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(
                    Circle()
                        .fill(isSelected ? Theme.accent : .clear)
                        .frame(width: 28, height: 28)
                )
        }
        .buttonStyle(.plain)
    }

    private func navButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }

    private func shiftMonth(_ delta: Int) {
        if let d = cal.date(byAdding: .month, value: delta, to: visibleMonth) {
            visibleMonth = d
        }
    }

    /// Cells for the visible month, padded with nils so the 1st lands on Monday.
    private var monthCells: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: visibleMonth) else { return [] }
        let first = interval.start
        let daysInMonth = cal.range(of: .day, in: .month, for: visibleMonth)?.count ?? 30
        // Monday-first offset
        let weekday = cal.component(.weekday, from: first)   // 1=Sun…7=Sat
        let leading = (weekday + 5) % 7                       // days before the 1st
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for d in 0..<daysInMonth {
            cells.append(cal.date(byAdding: .day, value: d, to: first))
        }
        return cells
    }
}

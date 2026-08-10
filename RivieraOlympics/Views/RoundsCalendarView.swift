import SwiftUI

/// Month calendar of saved rounds with course names on day cells.
/// Caller must pass the full round set (no list-count limit).
struct RoundsCalendarView: View {
    /// All rounds to place on the calendar (never capped by home list limit).
    var rounds: [GolfRound]
    @Binding var selectedDay: Date?

    private var calendar: Calendar { Calendar.current }

    private var roundsByDay: [Date: [GolfRound]] {
        Dictionary(grouping: rounds) { round in
            calendar.startOfDay(for: round.date)
        }
    }

    private var monthTitle: String {
        monthAnchor.formatted(.dateTime.year().month(.wide))
    }

    @State private var monthAnchor = Date()

    private var daysInMonthGrid: [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthAnchor)) else {
            return []
        }
        let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<31
        let firstWeekday = calendar.component(.weekday, from: monthStart) // 1=Sun
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(calendar.startOfDay(for: date))
            }
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    var body: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdayHeader
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(daysInMonthGrid.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(minHeight: 72)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            if selectedDay == nil {
                selectedDay = calendar.startOfDay(for: Date())
            }
            if let selectedDay {
                monthAnchor = selectedDay
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(RivieraTheme.fairway)
            }
            .buttonStyle(.borderless)

            Spacer()
            Text(monthTitle)
                .font(.headline)
            Spacer()

            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(RivieraTheme.fairway)
            }
            .buttonStyle(.borderless)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let dayRounds = roundsByDay[day] ?? []
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isToday = calendar.isDateInToday(day)
        let courseLabel = calendarCourseLabel(for: dayRounds)

        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 13, weight: isToday || isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)

                if !courseLabel.isEmpty {
                    Text(courseLabel)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.95) : RivieraTheme.fairwayDeep)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                } else {
                    Text(" ")
                        .font(.system(size: 8))
                }

                if dayRounds.count > 1 {
                    Text("+\(dayRounds.count - 1)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.9) : .secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(cellBackground(isSelected: isSelected, hasRounds: !dayRounds.isEmpty, isToday: isToday))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isToday && !isSelected ? RivieraTheme.fairway : Color.clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Short course name for the day cell (first round’s course).
    private func calendarCourseLabel(for rounds: [GolfRound]) -> String {
        guard let first = rounds.first else { return "" }
        let raw = first.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            let t = first.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.count <= 8 ? t : String(t.prefix(8))
        }
        return raw.count <= 8 ? raw : String(raw.prefix(8))
    }

    private func cellBackground(isSelected: Bool, hasRounds: Bool, isToday: Bool) -> Color {
        if isSelected { return RivieraTheme.fairway }
        if hasRounds { return RivieraTheme.fairway.opacity(0.16) }
        if isToday { return RivieraTheme.sand.opacity(0.45) }
        return Color(.tertiarySystemFill).opacity(0.55)
    }

    private func shiftMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = next
        }
    }
}

import SwiftUI

/// Month grid marking the days that carry a completed fast.
///
/// Respects the locale's first weekday, so the same view reads correctly for a
/// Monday-first Ukrainian user and a Sunday-first American one.
struct StreakCalendar: View {
    @Binding var anchor: Date
    let activeDays: Set<Date>

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(spacing: 12) {
            header

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                // Indexed, not `id: \.self`: very-short weekday symbols repeat
                // in every language Solura ships (S M T W T F S in English,
                // В П В С Ч П С in Russian), and identifying them by value
                // collapses the duplicates and leaves the header short.
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(Typography.overline)
                        .foregroundStyle(Palette.inkTertiary)
                }

                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 32)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(width: 32, height: 32)
            }

            Spacer()

            Text(anchor.formatted(.dateTime.month(.wide).year()))
                .font(Typography.cardTitle)
                .foregroundStyle(Palette.ink)

            Spacer()

            Button { step(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(canStepForward ? Palette.inkSecondary : Palette.hairline)
                    .frame(width: 32, height: 32)
            }
            .disabled(!canStepForward)
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isActive = activeDays.contains(calendar.startOfDay(for: day))
        let isToday = calendar.isDateInToday(day)

        return Text(verbatim: "\(calendar.component(.day, from: day))")
            .font(.system(.footnote, design: .rounded, weight: isActive ? .semibold : .regular))
            .foregroundStyle(isActive ? Palette.onAccent : Palette.inkSecondary)
            .frame(height: 32)
            .frame(maxWidth: .infinity)
            .background {
                if isActive {
                    Circle().fill(LinearGradient.fasting).frame(width: 32, height: 32)
                } else if isToday {
                    Circle().strokeBorder(Palette.accent.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                }
            }
            .accessibilityLabel(day.formatted(date: .long, time: .omitted))
            .accessibilityValue(isActive ? Text("history.calendar.fasted") : Text("history.calendar.none"))
    }

    // MARK: Grid maths

    /// Localised one-letter weekday headers, rotated to the locale's first day.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// One entry per cell: `nil` pads the leading days of the first week.
    private var days: [Date?] {
        guard
            let interval = calendar.dateInterval(of: .month, for: anchor),
            let count = calendar.range(of: .day, in: .month, for: anchor)?.count
        else { return [] }

        let weekday = calendar.component(.weekday, from: interval.start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7

        let dates: [Date?] = (0..<count).map {
            calendar.date(byAdding: .day, value: $0, to: interval.start)
        }
        return Array(repeating: nil, count: leading) + dates
    }

    private var canStepForward: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: anchor) else { return false }
        return next <= Date.now
    }

    private func step(_ months: Int) {
        guard let moved = calendar.date(byAdding: .month, value: months, to: anchor) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { anchor = moved }
    }
}

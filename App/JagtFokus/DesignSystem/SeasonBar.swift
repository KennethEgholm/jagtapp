import SwiftUI

/// The hunting year (1 April – 31 March) as a bar. Open periods are filled.
/// Decorative: callers carry the same facts in text and accessibility labels.
struct SeasonBar: View {
    let periods: [SeasonPeriod]
    /// Selected day. Only pass one when the screen has a date context.
    var marker: MonthDay?
    var showsMonths = false
    var height: CGFloat = 6
    /// Draws month gaps in the row background color.
    var gapColor: Color = Color(.secondarySystemGroupedBackground)

    private let timeline = SeasonTimeline()
    private static let initials = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.fill.tertiary)
                    ForEach(Array(timeline.segments(for: periods).enumerated()), id: \.offset) { _, segment in
                        Capsule()
                            .fill(Color.seasonOpen.gradient)
                            .frame(width: max(height, width * (segment.upperBound - segment.lowerBound)))
                            .offset(x: width * segment.lowerBound)
                    }
                    ForEach(timeline.months.dropFirst(), id: \.self) { month in
                        Rectangle()
                            .fill(gapColor)
                            .frame(width: 1)
                            .offset(x: width * timeline.position(ofMonth: month))
                    }
                }
            }
            .frame(height: height)
            .clipShape(Capsule())
            .overlay(alignment: .leading) {
                if let marker {
                    GeometryReader { geo in
                        Capsule()
                            .fill(.primary)
                            .overlay(Capsule().stroke(gapColor, lineWidth: 1))
                            .frame(width: 3, height: height + 8)
                            .offset(x: geo.size.width * timeline.position(of: marker) - 1.5, y: -4)
                    }
                }
            }
            .padding(.vertical, marker == nil ? 0 : 4)

            if showsMonths {
                HStack(spacing: 0) {
                    ForEach(timeline.months, id: \.self) { month in
                        Text(Self.initials[month - 1])
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 24) {
        SeasonBar(periods: [
            SeasonPeriod(from: MonthDay(month: 5, day: 16), to: MonthDay(month: 7, day: 15)),
            SeasonPeriod(from: MonthDay(month: 10, day: 1), to: MonthDay(month: 1, day: 31))
        ])
        SeasonBar(
            periods: [SeasonPeriod(from: MonthDay(month: 9, day: 1), to: MonthDay(month: 1, day: 31))],
            marker: MonthDay(month: 10, day: 11),
            showsMonths: true,
            height: 12
        )
    }
    .padding()
}

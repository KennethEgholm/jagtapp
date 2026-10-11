import Foundation

/// Maps dates onto the hunting year, 1 April – 31 March, as fractions 0...1.
/// Every period in the data is contiguous in that window.
public struct SeasonTimeline: Sendable {
    public static let startMonth = 4
    private static let daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    private static let length = 365.0

    public init() {}

    /// Calendar months in display order, April first.
    public var months: [Int] {
        (0..<12).map { (Self.startMonth - 1 + $0) % 12 + 1 }
    }

    /// Start of the day as a fraction of the hunting year.
    public func position(of day: MonthDay) -> Double {
        Double(ordinal(of: day)) / Self.length
    }

    /// Start of the month as a fraction of the hunting year.
    public func position(ofMonth month: Int) -> Double {
        position(of: MonthDay(month: month, day: 1))
    }

    /// Open stretches, end day inclusive. Split when a period crosses 1 April.
    public func segments(for periods: [SeasonPeriod]) -> [ClosedRange<Double>] {
        periods.flatMap { period -> [ClosedRange<Double>] in
            let start = Double(ordinal(of: period.from)) / Self.length
            let end = Double(ordinal(of: period.to) + 1) / Self.length
            if start < end { return [start...end] }
            return [0...end, start...1]
        }
        .sorted { $0.lowerBound < $1.lowerBound }
    }

    private func ordinal(of day: MonthDay) -> Int {
        let month = max(1, min(12, day.month))
        let length = Self.daysInMonth[month - 1]
        let dayInMonth = max(1, min(length, day.day))
        var offset = 0
        var current = Self.startMonth
        while current != month {
            offset += Self.daysInMonth[current - 1]
            current = current % 12 + 1
        }
        return offset + dayInMonth - 1
    }
}

import Foundation

public struct SeasonStatus: Sendable, Equatable {
    public var isOpen: Bool
    /// Open, and the last day is less than `soonWithinDays` away.
    public var isClosingSoon: Bool
    public var endDate: Date?
    /// 0 on the last day.
    public var daysLeft: Int?
    public var nextOpening: Date?
    public var daysUntilOpening: Int?
}

public struct SeasonCalendar: Sendable {
    public var calendar: Calendar
    /// Language for the display helpers. Danish is the source language, so pass the
    /// app's own language here rather than the device region.
    public var locale: Locale

    public init(
        timeZone: TimeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .gmt,
        locale: Locale = .autoupdatingCurrent
    ) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.locale = locale
    }

    public func monthDay(on date: Date) -> MonthDay {
        let parts = calendar.dateComponents([.month, .day], from: date)
        return MonthDay(month: parts.month ?? 1, day: parts.day ?? 1)
    }

    public func isOpen(_ species: Species, on date: Date) -> Bool {
        isOpen(species.periods, on: date)
    }

    public func isOpen(_ periods: [SeasonPeriod], on date: Date) -> Bool {
        let today = monthDay(on: date)
        return periods.contains { contains(today, in: $0) }
    }

    public func contains(_ day: MonthDay, in period: SeasonPeriod) -> Bool {
        if period.from <= period.to {
            return day >= period.from && day <= period.to
        }
        return day >= period.from || day <= period.to
    }

    public func nextOpening(of species: Species, after date: Date) -> Date? {
        nextOpening(of: species.periods, after: date)
    }

    public func nextOpening(of periods: [SeasonPeriod], after date: Date) -> Date? {
        if isOpen(periods, on: date) { return nil }
        let today = calendar.startOfDay(for: date)
        var soonest: Date?
        for period in periods {
            guard let candidate = nextStart(of: period.from, onOrAfter: today) else { continue }
            if soonest == nil || candidate < soonest! {
                soonest = candidate
            }
        }
        return soonest
    }

    /// Last day of the open period that contains `date`, or nil when closed.
    public func currentPeriodEnd(of periods: [SeasonPeriod], on date: Date) -> Date? {
        let day = monthDay(on: date)
        let start = calendar.startOfDay(for: date)
        let year = calendar.component(.year, from: start)
        var latest: Date?
        for period in periods where contains(day, in: period) {
            let wraps = period.from > period.to && day >= period.from
            guard let end = self.date(year: wraps ? year + 1 : year, monthDay: period.to) else { continue }
            if latest == nil || end > latest! {
                latest = end
            }
        }
        return latest
    }

    /// Open/closed state on a day, with the dates the UI shows next to it.
    public func status(of periods: [SeasonPeriod], on date: Date, soonWithinDays: Int = 7) -> SeasonStatus {
        if let end = currentPeriodEnd(of: periods, on: date) {
            let left = days(from: date, to: end)
            return SeasonStatus(
                isOpen: true,
                isClosingSoon: left < soonWithinDays,
                endDate: end,
                daysLeft: left,
                nextOpening: nil,
                daysUntilOpening: nil
            )
        }
        let next = nextOpening(of: periods, after: date)
        return SeasonStatus(
            isOpen: false,
            isClosingSoon: false,
            endDate: nil,
            daysLeft: nil,
            nextOpening: next,
            daysUntilOpening: next.map { days(from: date, to: $0) }
        )
    }

    /// Whole calendar days between two dates in Danish time.
    public func days(from start: Date, to end: Date) -> Int {
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// Year used to render a month and day on its own. A leap year, so 29 February survives.
    private static let displayYear = 2004

    /// Season text with short months: "16. maj – 15. jul og 1. okt – 31. jan".
    public func periodText(_ species: Species) -> String {
        periodText(species.periods)
    }

    public func periodText(_ periods: [SeasonPeriod]) -> String {
        guard !periods.isEmpty else { return String(localized: "Ingen jagttid") }
        return list(joining: periods.map { "\(short($0.from)) – \(short($0.to))" })
    }

    /// Day and month: "1. oktober" in Danish, "1 October" in English.
    public func full(_ day: MonthDay) -> String {
        display(day, .wide)
    }

    /// Short day and month: "11. okt" in Danish, "11 Oct" in English.
    public func short(_ day: MonthDay) -> String {
        display(day, .abbreviated)
    }

    /// Date with year: "11. okt 2026" in Danish, "11 Oct 2026" in English.
    public func shortWithYear(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
    }

    /// "søndag 11. oktober" in Danish, "Sunday 11 October" in English.
    public func longDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(locale))
    }

    /// "11. oktober 2026" in Danish, "11 October 2026" in English.
    /// The year is not grouped: 2026, never 2,026.
    public func fullWithYear(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide).year().locale(locale))
    }

    /// "oktober 2026", from a day key.
    public func monthYear(fromDayKey key: String) -> String? {
        guard let date = date(fromDayKey: key) else { return nil }
        return date.formatted(.dateTime.month(.wide).year().locale(locale))
    }

    /// Hunting year containing the date. 1 April starts the year named by that calendar year.
    public func huntingYear(on date: Date) -> Int {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return month >= SeasonTimeline.startMonth ? year : year - 1
    }

    /// "2026/27"
    public func huntingYearLabel(_ startYear: Int) -> String {
        String(format: "%d/%02d", startYear, (startYear + 1) % 100)
    }

    /// Calendar day in this timezone, `yyyy-MM-dd`.
    public func dayKey(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 1, parts.day ?? 1)
    }

    public func date(fromDayKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    /// Full month names, so VoiceOver reads "16. maj til 15. juli og 1. oktober til 31. januar".
    public func spokenPeriodText(_ periods: [SeasonPeriod]) -> String {
        guard !periods.isEmpty else { return String(localized: "Ingen jagttid") }
        let to = String(localized: "til")
        return list(joining: periods.map { "\(full($0.from)) \(to) \(full($0.to))" })
    }

    /// Month and day on their own have no year. Render them in a fixed one; only the
    /// month and the day reach the output.
    private func display(_ day: MonthDay, _ width: Date.FormatStyle.Symbol.Month) -> String {
        guard let date = date(year: Self.displayYear, monthDay: day) else { return "" }
        return date.formatted(.dateTime.day().month(width).locale(locale))
    }

    /// Joins with the locale's own list wording: "og" in Danish, "and" in English.
    private func list(joining parts: [String]) -> String {
        let formatter = ListFormatter()
        formatter.locale = locale
        return formatter.string(from: parts) ?? parts.joined(separator: ", ")
    }

    private func nextStart(of from: MonthDay, onOrAfter day: Date) -> Date? {
        let year = calendar.component(.year, from: day)
        if let thisYear = date(year: year, monthDay: from), thisYear >= day {
            return thisYear
        }
        return date(year: year + 1, monthDay: from)
    }

    private func date(year: Int, monthDay: MonthDay) -> Date? {
        var day = monthDay.day
        if monthDay.month == 2 && day == 29 {
            let leap = isLeapYear(year)
            if !leap { day = 28 }
        }
        return calendar.date(from: DateComponents(year: year, month: monthDay.month, day: day))
    }

    private func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }
}

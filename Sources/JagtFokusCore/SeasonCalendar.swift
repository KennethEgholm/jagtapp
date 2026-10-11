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

    public init(timeZone: TimeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .gmt) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "da_DK")
        calendar.timeZone = timeZone
        self.calendar = calendar
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

    public func danishPeriodText(_ species: Species) -> String {
        danishPeriodText(species.periods)
    }

    public func danishPeriodText(_ periods: [SeasonPeriod]) -> String {
        guard !periods.isEmpty else { return "Ingen jagttid" }
        return periods.map { period in
            "\(danish(period.from)) – \(danish(period.to))"
        }.joined(separator: " og ")
    }

    public func danish(_ day: MonthDay) -> String {
        let months = ["jan", "feb", "mar", "apr", "maj", "jun", "jul", "aug", "sep", "okt", "nov", "dec"]
        let monthName = months[max(0, min(11, day.month - 1))]
        return "\(day.day). \(monthName)"
    }

    public func danishDate(_ date: Date) -> String {
        let day = monthDay(on: date)
        let year = calendar.component(.year, from: date)
        return "\(danish(day)) \(year)"
    }

    /// "søndag 11. oktober"
    public func danishLongDate(_ date: Date) -> String {
        let weekdays = ["søndag", "mandag", "tirsdag", "onsdag", "torsdag", "fredag", "lørdag"]
        let weekday = calendar.component(.weekday, from: date)
        return "\(weekdays[(weekday - 1) % 7]) \(danishFull(monthDay(on: date)))"
    }

    /// "1. oktober"
    public func danishFull(_ day: MonthDay) -> String {
        let months = [
            "januar", "februar", "marts", "april", "maj", "juni",
            "juli", "august", "september", "oktober", "november", "december"
        ]
        return "\(day.day). \(months[max(0, min(11, day.month - 1))])"
    }

    /// Full month names, for VoiceOver.
    public func danishSpokenPeriodText(_ periods: [SeasonPeriod]) -> String {
        guard !periods.isEmpty else { return "Ingen jagttid" }
        return periods.map { period in
            "\(danishFull(period.from)) til \(danishFull(period.to))"
        }.joined(separator: " og ")
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

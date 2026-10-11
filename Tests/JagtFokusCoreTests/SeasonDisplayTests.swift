import Foundation
import Testing
@testable import JagtFokusCore

struct SeasonDisplayTests {
    let calendar = SeasonCalendar()

    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return calendar.calendar.date(from: components)!
    }

    func period(_ from: String, _ to: String) -> SeasonPeriod {
        SeasonPeriod(from: MonthDay.parse(from)!, to: MonthDay.parse(to)!)
    }

    func sameDay(_ lhs: Date?, _ rhs: Date) -> Bool {
        guard let lhs else { return false }
        return calendar.calendar.isDate(lhs, inSameDayAs: rhs)
    }

    @Test func periodEndCrossesNewYear() {
        let end = calendar.currentPeriodEnd(of: [period("10-01", "01-31")], on: date(2026, 10, 11))
        #expect(sameDay(end, date(2027, 1, 31)))
    }

    @Test func periodEndInJanuaryStaysInSameYear() {
        let end = calendar.currentPeriodEnd(of: [period("10-01", "01-31")], on: date(2027, 1, 10))
        #expect(sameDay(end, date(2027, 1, 31)))
    }

    @Test func periodEndPicksTheOpenPeriod() {
        let buck = [period("05-16", "07-15"), period("10-01", "01-31")]
        #expect(sameDay(calendar.currentPeriodEnd(of: buck, on: date(2026, 6, 1)), date(2026, 7, 15)))
        #expect(calendar.currentPeriodEnd(of: buck, on: date(2026, 8, 1)) == nil)
    }

    @Test func periodEndClampsLeapDay() {
        let end = calendar.currentPeriodEnd(of: [period("09-01", "02-29")], on: date(2026, 12, 1))
        #expect(sameDay(end, date(2027, 2, 28)))
    }

    @Test func daysCountsCalendarDays() {
        #expect(calendar.days(from: date(2026, 10, 11), to: date(2026, 10, 11)) == 0)
        #expect(calendar.days(from: date(2026, 10, 11), to: date(2026, 11, 1)) == 21)
        #expect(calendar.days(from: date(2026, 12, 30), to: date(2027, 1, 2)) == 3)
    }

    @Test func longDanishDateHasWeekdayAndFullMonth() {
        #expect(calendar.danishLongDate(date(2026, 10, 11)) == "søndag 11. oktober")
    }

    @Test func statusOpenFarFromEnd() {
        let status = calendar.status(of: [period("10-01", "01-31")], on: date(2026, 10, 11))
        #expect(status.isOpen)
        #expect(!status.isClosingSoon)
        #expect(status.daysLeft == 112)
        #expect(sameDay(status.endDate, date(2027, 1, 31)))
        #expect(status.nextOpening == nil)
    }

    @Test func statusClosingSoonWithinAWeek() {
        let status = calendar.status(of: [period("09-16", "10-15")], on: date(2026, 10, 11))
        #expect(status.isClosingSoon)
        #expect(status.daysLeft == 4)
        #expect(calendar.status(of: [period("09-16", "10-15")], on: date(2026, 10, 15)).daysLeft == 0)
    }

    @Test func statusClosedKnowsNextOpening() {
        let status = calendar.status(of: [period("11-01", "01-31")], on: date(2026, 10, 11))
        #expect(!status.isOpen)
        #expect(status.daysUntilOpening == 21)
        #expect(sameDay(status.nextOpening, date(2026, 11, 1)))
    }

    @Test func statusWithoutPeriodsNeverOpens() {
        let status = calendar.status(of: [], on: date(2026, 10, 11))
        #expect(!status.isOpen)
        #expect(status.nextOpening == nil)
        #expect(status.daysUntilOpening == nil)
    }

    @Test func spokenPeriodTextUsesFullMonths() {
        let buck = [period("05-16", "07-15"), period("10-01", "01-31")]
        #expect(calendar.danishSpokenPeriodText(buck) == "16. maj til 15. juli og 1. oktober til 31. januar")
        #expect(calendar.danishSpokenPeriodText([]) == "Ingen jagttid")
    }
}

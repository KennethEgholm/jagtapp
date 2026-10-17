import Foundation
import Testing
@testable import JagtFokusCore

/// Reference values: US Naval Observatory (aa.usno.navy.mil/api/rstt/oneday).
struct SunTimesTests {
    /// Danish is the source language. Pin the locale so the clock format does not depend on the machine.
    let calendar = SeasonCalendar(locale: Locale(identifier: "da_DK"))
    let english = SeasonCalendar(locale: Locale(identifier: "en_GB"))

    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// Minutes past midnight in Danish local time.
    func minutes(_ date: Date?) -> Int? {
        guard let date else { return nil }
        let parts = calendar.calendar.dateComponents([.hour, .minute], from: date)
        return parts.hour! * 60 + parts.minute!
    }

    func expect(_ times: SunTimes, rise: (Int, Int), set: (Int, Int), sourceLocation: SourceLocation = #_sourceLocation) {
        let r = rise.0 * 60 + rise.1
        let s = set.0 * 60 + set.1
        #expect(abs((minutes(times.sunrise) ?? -999) - r) <= 2, "solopgang \(String(describing: minutes(times.sunrise)))", sourceLocation: sourceLocation)
        #expect(abs((minutes(times.sunset) ?? -999) - s) <= 2, "solnedgang \(String(describing: minutes(times.sunset)))", sourceLocation: sourceLocation)
    }

    @Test func aarhusInOctober() {
        expect(calendar.sunTimes(on: date(2026, 10, 11), latitude: 56.1629, longitude: 10.2039), rise: (7, 42), set: (18, 29))
    }

    @Test func copenhagenAtMidsummer() {
        expect(calendar.sunTimes(on: date(2026, 6, 21), latitude: 55.6761, longitude: 12.5683), rise: (4, 25), set: (21, 58))
    }

    @Test func skagenAtMidwinter() {
        expect(calendar.sunTimes(on: date(2026, 12, 21), latitude: 57.7209, longitude: 10.5839), rise: (9, 0), set: (15, 32))
    }

    @Test func clocksGoBackOnLastSundayOfOctober() {
        expect(calendar.sunTimes(on: date(2026, 10, 24), latitude: 56.1629, longitude: 10.2039), rise: (8, 9), set: (17, 56))
        expect(calendar.sunTimes(on: date(2026, 10, 25), latitude: 56.1629, longitude: 10.2039), rise: (7, 12), set: (16, 54))
    }

    @Test func sunTimesBelongToTheRequestedDay() {
        let day = date(2026, 10, 11)
        let times = calendar.sunTimes(on: day, latitude: 56.1629, longitude: 10.2039)
        #expect(calendar.calendar.isDate(times.sunrise!, inSameDayAs: day))
        #expect(calendar.calendar.isDate(times.sunset!, inSameDayAs: day))
    }

    @Test func polarNightHasNoSunrise() {
        let times = calendar.sunTimes(on: date(2026, 12, 21), latitude: 78.22, longitude: 15.65)
        #expect(times.sunrise == nil)
        #expect(times.sunset == nil)
    }

    @Test func clockTimeUsesTheLocaleSeparator() {
        let time = calendar.calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 7, minute: 42))!
        #expect(calendar.clockTime(time) == "07.42")
        #expect(english.clockTime(time) == "07:42")
    }

    /// Danish time on the sun row, whatever zone the phone is set to.
    @Test func clockTimeIsInTheCalendarsTimeZone() throws {
        let auckland = SeasonCalendar(
            timeZone: try #require(TimeZone(identifier: "Pacific/Auckland")),
            locale: Locale(identifier: "da_DK")
        )
        let time = try #require(auckland.calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 7, minute: 42)))
        #expect(auckland.clockTime(time) == "07.42")
    }

    @Test func clockTimeRoundsToNearestMinute() {
        let late = calendar.calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 18, minute: 28, second: 40))!
        let early = calendar.calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 18, minute: 28, second: 20))!
        let midnight = calendar.calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 23, minute: 59, second: 50))!
        #expect(calendar.clockTime(late) == "18.29")
        #expect(calendar.clockTime(early) == "18.28")
        #expect(calendar.clockTime(midnight) == "00.00")
    }
}

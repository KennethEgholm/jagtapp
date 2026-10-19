import Foundation
import Testing
@testable import JagtFokusCore

/// Anchors: a solar eclipse is a new moon and a lunar eclipse is a full moon.
/// 1999-08-11: total solar eclipse over Europe. 2000-01-21: total lunar eclipse.
struct MoonPhaseTests {
    func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        return utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func theEclipseNewMoonIsNew() {
        let phase = MoonPhase(at: utc(1999, 8, 11, 11, 0))
        #expect(phase.name == .new)
        #expect(phase.illumination < 0.02)
    }

    @Test func theEclipseFullMoonIsFull() {
        let phase = MoonPhase(at: utc(2000, 1, 21, 4, 40))
        #expect(phase.name == .full)
        #expect(phase.illumination > 0.98)
    }

    /// Halfway between the reference new moon and the eclipse full moon.
    @Test func halfwayToFullIsFirstQuarter() {
        let phase = MoonPhase(at: utc(2000, 1, 14, 3, 52))
        #expect(phase.name == .firstQuarter)
        #expect(abs(phase.illumination - 0.5) < 0.06)
    }

    @Test func waningBeforeTheNextNewMoon() {
        let phase = MoonPhase(at: utc(2000, 2, 1, 12, 0))
        #expect(phase.name == .waningCrescent)
        #expect(phase.illumination < 0.5)
    }

    @Test func waxingAfterTheNewMoon() {
        let phase = MoonPhase(at: utc(2000, 1, 9, 12, 0))
        #expect(phase.name == .waxingCrescent)
        #expect(phase.illumination < 0.3)
    }

    @Test func illuminationStaysWithinOne() {
        // Every six hours across three synodic months.
        let start = utc(2026, 1, 1, 0, 0)
        for step in 0..<12 * 90 {
            let phase = MoonPhase(at: start.addingTimeInterval(Double(step) * 6 * 3600))
            #expect((0.0...1.0).contains(phase.illumination))
        }
    }

    /// The moon follows the calendar's time zone, like the sun times do.
    @Test func moonPhaseUsesTheCalendarsNoon() throws {
        let calendar = SeasonCalendar(locale: Locale(identifier: "da_DK"))
        let day = try #require(calendar.date(fromDayKey: "2000-01-21"))
        #expect(calendar.moonPhase(on: day).name == .full)
    }
}

import Foundation
import Testing
@testable import JagtFokusCore

struct SeasonTimelineTests {
    let timeline = SeasonTimeline()

    func period(_ from: String, _ to: String) -> SeasonPeriod {
        SeasonPeriod(from: MonthDay.parse(from)!, to: MonthDay.parse(to)!)
    }

    func close(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.0001
    }

    @Test func huntingYearStartsFirstOfApril() {
        #expect(timeline.position(of: MonthDay(month: 4, day: 1)) == 0)
        #expect(close(timeline.position(of: MonthDay(month: 3, day: 31)), 364.0 / 365.0))
    }

    @Test func winterSeasonIsOneSegment() {
        let segments = timeline.segments(for: [period("10-01", "01-31")])
        #expect(segments.count == 1)
        #expect(close(segments[0].lowerBound, 183.0 / 365.0))
        #expect(close(segments[0].upperBound, 306.0 / 365.0))
    }

    @Test func periodAcrossAprilFirstSplits() {
        let segments = timeline.segments(for: [period("03-01", "04-30")])
        #expect(segments.count == 2)
        #expect(close(segments[0].lowerBound, 0))
        #expect(close(segments[1].upperBound, 1))
    }

    @Test func leapDayEndsWithFebruary() {
        let segments = timeline.segments(for: [period("09-01", "02-29")])
        #expect(close(segments[0].upperBound, 334.0 / 365.0))
    }

    @Test func monthsStartInApril() {
        #expect(timeline.months.first == 4)
        #expect(timeline.months.last == 3)
        #expect(timeline.months.count == 12)
    }
}

import Foundation
import Testing
@testable import JagtFokusCore

struct BagJournalTests {
    let calendar = SeasonCalendar()

    func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func marchThirtyFirstBelongsToPreviousHuntingYear() {
        #expect(calendar.huntingYear(on: date(2027, 3, 31)) == 2026)
        #expect(calendar.huntingYear(on: date(2027, 4, 1)) == 2027)
        #expect(calendar.huntingYearLabel(2026) == "2026/27")
    }

    @Test func twoEntriesOfSameSpeciesSum() {
        var journal = BagJournal()
        journal.record(speciesId: "fasan", on: date(2026, 10, 14), placeId: nil, now: date(2026, 10, 14, hour: 8), calendar: calendar)
        journal.record(speciesId: "fasan", on: date(2026, 10, 20), placeId: "midtjylland", now: date(2026, 10, 20, hour: 9), calendar: calendar)
        journal.record(speciesId: "raabuk", on: date(2026, 11, 1), placeId: nil, now: date(2026, 11, 1, hour: 10), calendar: calendar)
        let summary = journal.summary(inHuntingYear: 2026, calendar: calendar)
        #expect(summary.pieces == 3)
        #expect(summary.speciesCount == 2)
    }

    @Test func plusOneIncreasesCount() {
        var journal = BagJournal()
        let entry = journal.record(
            speciesId: "raabuk",
            on: date(2026, 10, 14),
            placeId: nil,
            now: date(2026, 10, 14, hour: 16),
            calendar: calendar
        )
        #expect(entry.count == 1)
        #expect(entry.placeId == nil)
        journal.increment(id: entry.id)
        #expect(journal.entries.count == 1)
        #expect(journal.entries[0].count == 2)
    }

    @Test func undoRemovesTheEntry() {
        var journal = BagJournal()
        let entry = journal.record(
            speciesId: "raabuk",
            on: date(2026, 10, 14),
            placeId: nil,
            now: date(2026, 10, 14),
            calendar: calendar
        )
        journal.remove(id: entry.id)
        #expect(journal.entries.isEmpty)
    }

    @Test func entryWithoutPlaceRoundTrips() throws {
        var journal = BagJournal()
        journal.record(speciesId: "hare", on: date(2026, 10, 1), placeId: nil, now: date(2026, 10, 1), calendar: calendar)
        let decoded = try BagJournal.decode(from: journal.encoded())
        #expect(decoded.entries.count == 1)
        #expect(decoded.entries[0].placeId == nil)
        #expect(decoded.entries[0].date == "2026-10-01")
    }

    @Test func aprilFirstStartsANewYear() {
        var journal = BagJournal()
        journal.record(speciesId: "raabuk", on: date(2027, 3, 31), placeId: nil, now: date(2027, 3, 31), calendar: calendar)
        journal.record(speciesId: "raabuk", on: date(2027, 4, 1), placeId: nil, now: date(2027, 4, 1), calendar: calendar)
        #expect(journal.summary(inHuntingYear: 2026, calendar: calendar).pieces == 1)
        #expect(journal.summary(inHuntingYear: 2027, calendar: calendar).pieces == 1)
    }
}

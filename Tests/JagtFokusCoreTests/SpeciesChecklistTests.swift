import Foundation
import Testing
@testable import JagtFokusCore

struct SpeciesChecklistTests {
    let calendar = SeasonCalendar()

    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func addIsIdempotent() {
        var list = SpeciesChecklist()
        list.add("fasan")
        list.add("fasan")
        list.add("raabuk")
        #expect(list.ids == ["fasan", "raabuk"])
        #expect(list.contains("fasan"))
    }

    @Test func removeDoesNotAffectOtherSpecies() {
        var list = SpeciesChecklist(ids: ["fasan", "raabuk"])
        list.remove("fasan")
        #expect(list.ids == ["raabuk"])
        list.remove("fasan")
        #expect(list.contains("raabuk"))
    }

    @Test func seedUsesEachJournalSpeciesOnce() {
        var journal = BagJournal()
        journal.record(speciesId: "fasan", on: date(2026, 10, 1), placeId: nil, now: date(2026, 10, 1), calendar: calendar)
        journal.record(speciesId: "fasan", on: date(2026, 10, 2), placeId: nil, now: date(2026, 10, 2), calendar: calendar)
        journal.record(speciesId: "hare", on: date(2026, 11, 1), placeId: "als", now: date(2026, 11, 1), calendar: calendar)
        let list = SpeciesChecklist.seeded(from: journal)
        #expect(list.ids == ["fasan", "hare"])
    }

    @Test func removingAJournalEntryDoesNotChangeASavedList() {
        var journal = BagJournal()
        let entry = journal.record(speciesId: "fasan", on: date(2026, 10, 1), placeId: nil, now: date(2026, 10, 1), calendar: calendar)
        let list = SpeciesChecklist.seeded(from: journal)
        journal.remove(id: entry.id)
        #expect(journal.entries.isEmpty)
        #expect(list.contains("fasan"))
    }

    @Test func roundTripSortsIds() throws {
        let list = SpeciesChecklist(ids: ["raabuk", "fasan"])
        let decoded = try SpeciesChecklist.decode(from: list.encoded())
        #expect(decoded == list)
    }
}

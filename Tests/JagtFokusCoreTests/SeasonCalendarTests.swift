import Foundation
import Testing
@testable import JagtFokusCore

struct SeasonCalendarTests {
    let calendar = SeasonCalendar()
    let catalog: HuntingCatalog

    init() throws {
        let url = Self.repoRoot.appending(path: "data/jagttider.json")
        catalog = try HuntingCatalog.decode(from: Data(contentsOf: url))
    }

    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return calendar.calendar.date(from: components)!
    }

    func species(_ id: String) -> Species {
        catalog.allSpecies.first { $0.id == id }!
    }

    @Test func catalogHasGroupedSpecies() {
        #expect(catalog.groups.count == 10)
        #expect(catalog.allSpecies.count >= 40)
        #expect(catalog.version == 4)
    }

    @Test func octoberTenthOpensRoeAndClosesHare() {
        let day = date(2026, 10, 10)
        #expect(calendar.isOpen(species("raabuk"), on: day))
        #expect(calendar.isOpen(species("raa_og_lam"), on: day))
        #expect(calendar.isOpen(species("fasan"), on: day))
        #expect(!calendar.isOpen(species("hare"), on: day))
        #expect(!calendar.isOpen(species("ringdue"), on: day))
        #expect(!calendar.isOpen(species("kronhjort"), on: day))
    }

    @Test func yearWrapIncludesJanuary() {
        let day = date(2027, 1, 10)
        #expect(calendar.isOpen(species("raabuk"), on: day))
        #expect(calendar.isOpen(species("raev"), on: day))
        #expect(!calendar.isOpen(species("graaand"), on: day))
    }

    @Test func buckHasTwoPeriods() {
        #expect(calendar.isOpen(species("raabuk"), on: date(2026, 5, 16)))
        #expect(calendar.isOpen(species("raabuk"), on: date(2026, 7, 15)))
        #expect(!calendar.isOpen(species("raabuk"), on: date(2026, 7, 16)))
        #expect(!calendar.isOpen(species("raabuk"), on: date(2026, 9, 30)))
        #expect(calendar.isOpen(species("raabuk"), on: date(2026, 10, 1)))
    }

    @Test func augustGooseIsSeparateEntry() {
        let august = date(2026, 8, 15)
        #expect(calendar.isOpen(species("graagaas_omdrift"), on: august))
        #expect(!calendar.isOpen(species("graagaas"), on: august))
        #expect(calendar.isOpen(species("graagaas"), on: date(2026, 9, 1)))
    }

    @Test func nextOpeningForClosedHare() {
        let next = calendar.nextOpening(of: species("hare"), after: date(2026, 10, 10))
        let expected = date(2026, 11, 1)
        #expect(calendar.calendar.isDate(next!, inSameDayAs: expected))
    }

    @Test func nextOpeningIsNilWhenOpen() {
        #expect(calendar.nextOpening(of: species("fasan"), after: date(2026, 10, 10)) == nil)
    }

    @Test func kronkalvIncludesFeb28InNonLeapYear() {
        #expect(calendar.isOpen(species("kronkalv"), on: date(2027, 2, 28)))
        #expect(!calendar.isOpen(species("kronkalv"), on: date(2027, 3, 1)))
    }

    @Test func danishPeriodTextJoinsTwoSeasons() {
        let text = calendar.danishPeriodText(species("raabuk"))
        #expect(text == "16. maj – 15. jul og 1. okt – 31. jan")
    }
}

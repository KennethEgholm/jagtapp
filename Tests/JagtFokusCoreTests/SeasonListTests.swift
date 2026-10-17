import Foundation
import Testing
@testable import JagtFokusCore

struct SeasonListTests {
    let calendar = SeasonCalendar(locale: Locale(identifier: "da_DK"))

    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func species(_ id: String, _ name: String, _ periods: [(String, String)]) -> ResolvedSpecies {
        let periods = periods.map { SeasonPeriod(from: MonthDay.parse($0.0)!, to: MonthDay.parse($0.1)!) }
        return ResolvedSpecies(species: Species(id: id, name: name, periods: periods, note: nil), periods: periods, note: nil)
    }

    var groups: [ResolvedGroup] {
        [
            ResolvedGroup(id: "pattedyr", title: "Pattedyr", species: [
                species("raev", "Ræv", [("09-01", "01-31")]),
                species("hare", "Hare", [("10-01", "12-15")]),
                species("ilder", "Ilder", [])
            ]),
            ResolvedGroup(id: "fugle", title: "Fugle", species: [
                species("gaas", "Grågås", [("09-01", "10-20")]),
                species("and", "And", [("11-01", "12-31")]),
                species("bramgaas", "Bramgås", [("11-01", "12-31")])
            ]),
            ResolvedGroup(id: "lukket", title: "Lukket", species: [
                species("sneppe", "Sneppe", [("10-01", "10-10")])
            ])
        ]
    }

    @Test func openGroupsKeepOnlyOpenSpeciesAndDropEmptyGroups() {
        let open = calendar.openGroups(groups, on: date(2026, 10, 17))
        #expect(open.map(\.id) == ["pattedyr", "fugle"])
        #expect(open[0].species.map(\.id) == ["raev", "hare"])
        #expect(open[1].species.map(\.id) == ["gaas"])
    }

    @Test func closedSpeciesSortBySoonestOpeningThenName() {
        let closed = calendar.closedSpecies(groups, on: date(2026, 10, 17))
        // And and Bramgås both open 1 Nov: name decides. Sneppe opens next October. Ilder has no season and goes last.
        #expect(closed.map(\.id) == ["and", "bramgaas", "sneppe", "ilder"])
    }

    @Test func closingSoonCountsOpenSpeciesWithLastDayWithinAWeek() {
        // Grågås ends 20 Oct: 3 days left. Ræv and Hare run for weeks yet.
        #expect(calendar.closingSoonCount(groups, on: date(2026, 10, 17)) == 1)
        #expect(calendar.closingSoonCount(groups, on: date(2026, 10, 1)) == 0)
    }
}

struct TextSearchTests {
    @Test func ignoresCaseAndAccents() {
        #expect(TextSearch.matches("Ræv", query: "RÆV"))
        #expect(TextSearch.matches("Grågås", query: "gragas"))
        #expect(TextSearch.matches("Dåhjort", query: "då"))
    }

    @Test func trimsAndTreatsEmptyAsEverything() {
        #expect(TextSearch.matches("Råbuk", query: "  råb "))
        #expect(TextSearch.matches("Råbuk", query: "   "))
    }

    @Test func missesWhatIsNotThere() {
        #expect(!TextSearch.matches("Råbuk", query: "hjort"))
    }

    @Test func anyNameCanMatch() {
        #expect(TextSearch.matches(any: ["Als", "Sønderborg"], query: "SØNDER"))
        #expect(!TextSearch.matches(any: ["Als", "Sønderborg"], query: "Ærø"))
    }
}

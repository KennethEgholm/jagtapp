import Foundation
import Testing
@testable import JagtFokusCore

/// A downloaded file reaches every phone. These are the reasons to keep the data the app has.
struct CatalogCheckTests {
    static let law = "https://www.retsinformation.dk/eli/lta/2024/470"

    func catalog(
        species: [Species] = [Species(id: "raev", name: "Ræv", periods: [], note: nil)],
        places: [Place] = [
            Place(id: "dk", name: "Danmark", kind: .country, parentId: nil, matchNames: []),
            Place(id: "als", name: "Als", kind: .island, parentId: "dk", matchNames: [])
        ],
        overrides: [LocalOverride] = [LocalOverride(speciesId: "raev", placeId: "als", periods: [], note: nil)],
        source: String = law
    ) -> HuntingCatalog {
        HuntingCatalog(
            version: 1,
            updated: "1. juli 2024",
            sourceName: "BEK 470/2024",
            sourceURL: source,
            groups: species.isEmpty ? [] : [SpeciesGroup(id: "pattedyr", title: "Pattedyr", species: species)],
            places: places,
            overrides: overrides
        )
    }

    @Test func bundledDataPasses() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "data/jagttider.json")
        let bundled = try HuntingCatalog.decode(from: Data(contentsOf: url))
        #expect(bundled.problems == [])
    }

    @Test func soundCatalogHasNoProblems() {
        #expect(catalog().problems == [])
    }

    @Test func catalogWithoutSpeciesIsRefused() {
        #expect(catalog(species: [], overrides: []).problems == [.noSpecies])
    }

    @Test func catalogWithoutDenmarkIsRefused() {
        #expect(catalog(places: [], overrides: []).problems == [.noDenmark])
    }

    @Test func repeatedSpeciesIsRefused() {
        let fox = Species(id: "raev", name: "Ræv", periods: [], note: nil)
        #expect(catalog(species: [fox, fox]).problems == [.repeatedSpecies("raev")])
    }

    @Test func repeatedPlaceIsRefused() {
        let places = [
            Place(id: "dk", name: "Danmark", kind: .country, parentId: nil, matchNames: []),
            Place(id: "als", name: "Als", kind: .island, parentId: "dk", matchNames: []),
            Place(id: "als", name: "Als igen", kind: .island, parentId: "dk", matchNames: [])
        ]
        #expect(catalog(places: places).problems == [.repeatedPlace("als")])
    }

    @Test func placeUnderUnknownParentIsRefused() {
        let places = [
            Place(id: "dk", name: "Danmark", kind: .country, parentId: nil, matchNames: []),
            Place(id: "als", name: "Als", kind: .island, parentId: "syddanmark", matchNames: [])
        ]
        #expect(catalog(places: places).problems == [.unknownParent(place: "als", parent: "syddanmark")])
    }

    @Test func overrideForUnknownSpeciesIsRefused() {
        let overrides = [LocalOverride(speciesId: "ulv", placeId: "als", periods: [], note: nil)]
        #expect(catalog(overrides: overrides).problems == [.overrideForUnknownSpecies("ulv")])
    }

    @Test func overrideForUnknownPlaceIsRefused() {
        let overrides = [LocalOverride(speciesId: "raev", placeId: "anholt", periods: [], note: nil)]
        #expect(catalog(overrides: overrides).problems == [.overrideForUnknownPlace("anholt")])
    }

    @Test(arguments: [
        "http://www.retsinformation.dk/eli/lta/2024/470",
        "https://retsinformation.dk.example.com/eli/lta/2024/470",
        "https://www.retsinformation.dk@example.com/eli",
        "https://example.com/?u=https://www.retsinformation.dk",
        "jagtfokus://open",
        "javascript:alert(1)",
        ""
    ])
    func sourceOutsideRetsinformationIsRefused(source: String) {
        #expect(catalog(source: source).problems == [.untrustedSource(source)])
        #expect(catalog(source: source).sourceLink == nil)
    }

    @Test(arguments: [
        "https://www.retsinformation.dk/eli/lta/2024/470",
        "https://retsinformation.dk/eli/lta/2025/12",
        "https://WWW.Retsinformation.DK/eli/lta/2024/470"
    ])
    func sourceOnRetsinformationIsALink(source: String) {
        #expect(catalog(source: source).problems == [])
        #expect(catalog(source: source).sourceLink == URL(string: source))
    }

    @Test func decodeCheckedRefusesAFileWithProblems() throws {
        let data = try JSONEncoder().encode(catalog(species: [], overrides: []))
        #expect(throws: CatalogRefused(problems: [.noSpecies])) {
            try HuntingCatalog.decodeChecked(from: data)
        }
    }

    @Test func decodeCheckedReturnsASoundFile() throws {
        let data = try JSONEncoder().encode(catalog())
        #expect(try HuntingCatalog.decodeChecked(from: data) == catalog())
    }
}

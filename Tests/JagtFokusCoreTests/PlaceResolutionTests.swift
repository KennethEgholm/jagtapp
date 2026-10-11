import Foundation
import Testing
@testable import JagtFokusCore

struct PlaceResolutionTests {
    let calendar = SeasonCalendar()
    let catalog: HuntingCatalog

    init() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "data/jagttider.json")
        catalog = try HuntingCatalog.decode(from: Data(contentsOf: url))
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

    func place(_ id: String) -> Place {
        catalog.place(id: id)!
    }

    @Test func catalogHasPlacesAndOverrides() {
        #expect(catalog.version == 4)
        #expect(catalog.places.count >= 10)
        #expect(!catalog.overrides.isEmpty)
    }

    @Test func gpsAarhusMapsToMidtjylland() {
        let matched = catalog.matchPlace(names: ["Aarhus", "Region Midtjylland"])
        #expect(matched.id == "midtjylland")
    }

    @Test func gpsEndelaveBeatsMidtjylland() {
        let matched = catalog.matchPlace(names: ["Endelave", "Horsens", "Region Midtjylland"])
        #expect(matched.id == "endelave")
    }

    @Test func townsContainingIslandNamesDoNotMatchIsland() {
        #expect(catalog.matchPlace(names: ["Hals", "Aalborg Kommune", "Region Nordjylland"]).id == "nordjylland")
        #expect(catalog.matchPlace(names: ["Nørre Alslev", "Guldborgsund Kommune", "Region Sjælland"]).id == "lolland_falster")
        #expect(catalog.matchPlace(names: ["Ry", "Skanderborg Kommune", "Region Midtjylland"]).id == "midtjylland")
    }

    @Test func streetNamesDoNotMatchIsland() {
        let matched = catalog.matchPlace(names: ["Marstalsgade 1", "København", "Region Hovedstaden"])
        #expect(matched.id == "hovedstaden_kyst")
    }

    @Test func kommuneSuffixIsIgnored() {
        #expect(catalog.matchPlace(names: ["Tønder Kommune", "Region Syddanmark"]).id == "syddanmark_vest")
        #expect(catalog.matchPlace(names: ["Nordborg", "Sønderborg Kommune", "Region Syddanmark"]).id == "als")
    }

    @Test func hareClosedOnEndelaveWhenOpenInMidtjylland() {
        let nov = date(2026, 11, 10)
        let midt = catalog.resolved(species("hare"), at: place("midtjylland"))
        let island = catalog.resolved(species("hare"), at: place("endelave"))
        #expect(calendar.isOpen(midt.periods, on: nov))
        #expect(!calendar.isOpen(island.periods, on: nov))
    }

    @Test func saedgaasOnlyOpenOnLolland() {
        let sep = date(2026, 9, 15)
        let dk = catalog.resolved(species("saedgaas"), at: place("dk"))
        let lolland = catalog.resolved(species("saedgaas"), at: place("lolland_falster"))
        #expect(!calendar.isOpen(dk.periods, on: sep))
        #expect(calendar.isOpen(lolland.periods, on: sep))
    }

    @Test func resolvedSpeciesNamesItsLocalPlace() {
        let als = catalog.resolved(species("raabuk"), at: place("als"))
        let dk = catalog.resolved(species("raabuk"), at: place("dk"))
        #expect(als.localPlaceId == "als")
        #expect(als.isLocal)
        #expect(dk.localPlaceId == nil)
        #expect(!dk.isLocal)
    }

    @Test func regionOverrideAppliesOnIslandBelowIt() {
        let resolved = catalog.resolved(species("agerhoene"), at: place("als"))
        #expect(resolved.localPlaceId == "syddanmark")
    }

    @Test func resolvedSectionsKeepAllGroupsAndSpecies() {
        let sections = catalog.resolvedSections(at: place("sejero"))
        #expect(sections.map(\.id) == catalog.groups.map(\.id))
        #expect(sections.flatMap(\.species).count == catalog.allSpecies.count)
        let hare = sections.flatMap(\.species).first { $0.id == "hare" }!
        #expect(hare.isLocal)
        #expect(hare.generalPeriods == species("hare").periods)
    }

    @Test func localTimeCountPerPlace() {
        #expect(catalog.localTimeCount(at: "als") == 5)
        #expect(catalog.localTimeCount(at: "dk") == 0)
    }

    @Test func localTimeDoesNotRepeatGeneralNote() {
        let hare = catalog.resolved(species("hare"), at: place("midtjylland"))
        #expect(hare.isLocal)
        #expect(hare.note == nil)
    }

    @Test func localTimeKeepsItsOwnNote() {
        let fasan = catalog.resolved(species("fasan"), at: place("sejero"))
        #expect(fasan.note == "Hane 1. nov–31. jan. Høne kun 16. nov–30. nov.")
    }

    @Test func generalNoteStaysWithoutLocalTime() {
        let hare = catalog.resolved(species("hare"), at: place("dk"))
        #expect(hare.note == "Der findes lokale jagttider.")
    }

    /// The badge says "Lokal jagttid" and the period says "Ingen jagttid". Notes must add more.
    @Test func overrideNotesDoNotRestateTheUI() {
        let restated: Set<String> = ["Lokal jagttid.", "Ingen jagttid her."]
        let notes = catalog.overrides.compactMap(\.note)
        #expect(notes.allSatisfy { !restated.contains($0) })
    }

    @Test func everyPlaceHasCoordinatesInDenmark() {
        for place in catalog.places {
            #expect(place.latitude != nil && place.longitude != nil, "\(place.id) mangler lat/lon")
            let point = catalog.coordinate(for: place)
            #expect((54.5...57.8).contains(point?.latitude ?? 0), "\(place.id)")
            #expect((8.0...15.2).contains(point?.longitude ?? 0), "\(place.id)")
        }
    }

    @Test func coordinateFallsBackToParent() {
        let parent = Place(id: "p", name: "P", kind: .region, parentId: nil, matchNames: [], latitude: 56, longitude: 10)
        let child = Place(id: "c", name: "C", kind: .island, parentId: "p", matchNames: [])
        let small = HuntingCatalog(version: 1, updated: "", sourceName: "", sourceURL: "", groups: [], places: [parent, child])
        #expect(small.coordinate(for: child)?.latitude == 56)
        #expect(small.coordinate(for: child)?.longitude == 10)
    }

    @Test func alsShortensAutumnRoe() {
        let oct = date(2026, 10, 10)
        let dk = catalog.resolved(species("raabuk"), at: place("dk"))
        let als = catalog.resolved(species("raabuk"), at: place("als"))
        #expect(calendar.isOpen(dk.periods, on: oct))
        #expect(!calendar.isOpen(als.periods, on: oct))
    }
}

import Foundation
import Testing
@testable import JagtFokusCore

struct SpeciesBiologyTests {
    let catalog: HuntingCatalog
    let biology: BiologyCatalog

    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    init() throws {
        let root = Self.repoRoot
        catalog = try HuntingCatalog.decode(from: Data(contentsOf: root.appending(path: "data/jagttider.json")))
        biology = try BiologyCatalog.decode(from: Data(contentsOf: root.appending(path: "App/JagtFokus/Resources/biologi.json")))
    }

    @Test func everySpeciesHasBiology() {
        let missing = catalog.allSpecies.map(\.id).filter { biology.biology(for: $0) == nil }
        #expect(missing.isEmpty, "Mangler biologi: \(missing)")
    }

    @Test func noStaleSpeciesIds() {
        let known = Set(catalog.allSpecies.map(\.id))
        let stale = biology.species.keys.filter { !known.contains($0) }
        #expect(stale.isEmpty, "Ukendte art-id: \(stale)")
    }

    @Test func everyTaxonIsUsed() {
        let used = Set(biology.species.values)
        #expect(Set(biology.taxa.keys) == used)
    }

    @Test func sexClassesShareTheSpecies() {
        #expect(biology.species["kronhjort"] == biology.species["kronhind"])
        #expect(biology.species["raabuk"] == biology.species["raa_og_lam"])
        #expect(biology.species["graagaas"] == biology.species["graagaas_omdrift"])
        #expect(biology.biology(for: "edderfugl_han")?.latin == "Somateria mollissima")
    }

    /// Life history only. No stock counts that go stale, and no weak hosts.
    @Test func factsAreSourcedAndStable() {
        let allowedHosts = ["dofbasen.dk", "arter.dk", "lex.dk", "sgavmst.dk"]
        let invasiveURL = "https://sgavmst.dk/natur-og-jagt/regulering-og-udsaetning-af-vildt/regulering-af-vildt/regulering-af-invasive-arter"
        for (id, taxon) in biology.taxa {
            #expect(!taxon.latin.isEmpty, "\(id)")
            #expect(taxon.facts.map(\.label) == ["I Danmark", "Yngel"], "\(id)")
            #expect(!taxon.sources.isEmpty, "\(id)")
            for fact in taxon.facts {
                #expect(!fact.value.isEmpty, "\(id) \(fact.label)")
                #expect(fact.value == fact.value.trimmingCharacters(in: .whitespacesAndNewlines), "\(id)")
                #expect(!fact.value.contains("Wikipedia"), "\(id)")
            }
            var hosts: [String] = []
            for source in taxon.sources {
                #expect(!source.name.isEmpty, "\(id)")
                #expect(source.url.hasPrefix("https://"), "\(id) \(source.url)")
                let host = URL(string: source.url)?.host ?? ""
                #expect(allowedHosts.contains { host == $0 || host.hasSuffix(".\($0)") }, "\(id) \(host)")
                hosts.append(source.url)
            }
            let saysInvasive = taxon.facts.contains { $0.value.contains("Invasiv") }
            if saysInvasive {
                #expect(hosts.contains(invasiveURL), "\(id) siger invasiv uden myndighedskilde")
            }
        }
    }
}

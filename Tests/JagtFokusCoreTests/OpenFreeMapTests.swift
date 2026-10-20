import Foundation
import Testing
@testable import JagtFokusCore

struct OpenFreeMapTests {
    @Test func tilesTemplateFromTileJSON() throws {
        let json = """
        {"tiles":["https://tiles.openfreemap.org/planet/20261015_001001_pt/{z}/{x}/{y}.pbf"],"maxzoom":14}
        """
        let template = try OpenFreeMap.tilesTemplate(fromTileJSON: Data(json.utf8))
        #expect(template == "https://tiles.openfreemap.org/planet/20261015_001001_pt/{z}/{x}/{y}.pbf")
    }

    @Test func tileJSONWithoutTilesThrows() {
        #expect(throws: (any Error).self) {
            try OpenFreeMap.tilesTemplate(fromTileJSON: Data(#"{"maxzoom":14}"#.utf8))
        }
        #expect(throws: (any Error).self) {
            try OpenFreeMap.tilesTemplate(fromTileJSON: Data(#"{"tiles":[]}"#.utf8))
        }
    }

    @Test func constants() {
        #expect(OpenFreeMap.styleURL.absoluteString == "https://tiles.openfreemap.org/styles/liberty")
        #expect(OpenFreeMap.tileJSONURL.absoluteString == "https://tiles.openfreemap.org/planet")
        #expect(OpenFreeMap.maxParallelRequests == 4)
        #expect(OpenFreeMap.packZoom == 8...14)
    }
}

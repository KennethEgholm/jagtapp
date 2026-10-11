import Foundation
import Testing
@testable import JagtFokusCore

struct SpeciesPhotoTests {
    let catalog: HuntingCatalog
    let photos: SpeciesPhotos

    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    init() throws {
        let root = Self.repoRoot
        catalog = try HuntingCatalog.decode(from: Data(contentsOf: root.appending(path: "data/jagttider.json")))
        photos = try SpeciesPhotos.decode(from: Data(contentsOf: root.appending(path: "App/JagtFokus/Resources/species-photos.json")))
    }

    @Test func everySpeciesHasAPhoto() {
        let missing = catalog.allSpecies.map(\.id).filter { photos.photo(for: $0) == nil }
        #expect(missing.isEmpty, "Mangler foto: \(missing)")
    }

    @Test func sharedPhotoResolvesToItsOwner() {
        #expect(photos.photo(for: "graagaas_omdrift")?.id == "graagaas")
        #expect(photos.photo(for: "graagaas")?.id == "graagaas")
    }

    /// App Store: only licenses that allow commercial use.
    @Test func licensesAllowCommercialUse() {
        for photo in photos.photos.values {
            #expect(photo.allowsCommercialUse, "\(photo.file): \(photo.license)")
        }
    }

    @Test func licensesMatchCommercialRule() {
        func photo(_ license: String) -> SpeciesPhoto {
            SpeciesPhoto(file: "f", artist: "a", license: license, licenseURL: nil, sourceURL: "s")
        }
        #expect(photo("CC BY-SA 4.0").allowsCommercialUse)
        #expect(photo("CC BY 2.0").allowsCommercialUse)
        #expect(photo("CC0").allowsCommercialUse)
        #expect(photo("Public domain").allowsCommercialUse)
        #expect(!photo("CC BY-NC 4.0").allowsCommercialUse)
        #expect(!photo("CC BY-ND 4.0").allowsCommercialUse)
        #expect(!photo("GFDL").allowsCommercialUse)
        #expect(!photo("CC BY-NC-SA 2.0").allowsCommercialUse)
        #expect(photo("CC BY-SA 3.0 at").allowsCommercialUse)
    }

    @Test func everyPhotoIsCredited() {
        for photo in photos.photos.values {
            #expect(!photo.artist.isEmpty, "\(photo.file)")
            #expect(photo.sourceURL.hasPrefix("https://commons.wikimedia.org/"), "\(photo.file)")
        }
    }

    @Test func everyPhotoHasAnImageAsset() {
        let folder = Self.repoRoot.appending(path: "App/JagtFokus/Assets.xcassets/SpeciesPhotos")
        for id in photos.photos.keys {
            let jpg = folder.appending(path: "photo-\(id).imageset/\(id).jpg")
            #expect(FileManager.default.fileExists(atPath: jpg.path), "Mangler billede: \(jpg.lastPathComponent)")
        }
    }

    @Test func noUnusedPhotos() {
        let used = Set(photos.species.values)
        #expect(Set(photos.photos.keys) == used)
    }
}

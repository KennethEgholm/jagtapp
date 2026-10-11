import Foundation

/// Photo credits from `App/JagtFokus/Resources/species-photos.json`.
/// Image files live in the asset catalog as `photo-<id>`.
public struct SpeciesPhotos: Codable, Sendable, Equatable {
    /// Keyed by photo id.
    public var photos: [String: SpeciesPhoto]
    /// Species id → photo id. Several species may share one photo.
    public var species: [String: String]

    public static func decode(from data: Data) throws -> SpeciesPhotos {
        try JSONDecoder().decode(SpeciesPhotos.self, from: data)
    }

    public func photo(for speciesId: String) -> IdentifiedPhoto? {
        guard let id = species[speciesId], let photo = photos[id] else { return nil }
        return IdentifiedPhoto(id: id, photo: photo)
    }
}

public struct IdentifiedPhoto: Sendable, Equatable, Identifiable {
    public var id: String
    public var photo: SpeciesPhoto

    /// Asset catalog name.
    public var assetName: String { "photo-\(id)" }
}

public struct SpeciesPhoto: Codable, Sendable, Equatable {
    /// Wikimedia Commons file title.
    public var file: String
    public var artist: String
    public var license: String
    public var licenseURL: String?
    /// Commons file page. Shows full license and author.
    public var sourceURL: String

    enum CodingKeys: String, CodingKey {
        case file, artist, license
        case licenseURL = "license_url"
        case sourceURL = "source_url"
    }

    public init(file: String, artist: String, license: String, licenseURL: String?, sourceURL: String) {
        self.file = file
        self.artist = artist
        self.license = license
        self.licenseURL = licenseURL
        self.sourceURL = sourceURL
    }

    /// CC0, public domain, CC BY and CC BY-SA. Never NC or ND.
    public var allowsCommercialUse: Bool {
        let value = license.lowercased()
        if value.contains("-nc") || value.contains("-nd") { return false }
        return value == "cc0"
            || value.hasPrefix("public domain")
            || value.hasPrefix("cc by ")
            || value.hasPrefix("cc by-sa ")
    }
}

import Foundation

/// Why a downloaded catalog must not replace the one the app has.
public enum CatalogProblem: Equatable, Sendable {
    case noSpecies
    case noDenmark
    case repeatedSpecies(String)
    case repeatedPlace(String)
    case unknownParent(place: String, parent: String)
    case overrideForUnknownSpecies(String)
    case overrideForUnknownPlace(String)
    case untrustedSource(String)
}

public struct CatalogRefused: Error, Equatable, Sendable {
    public var problems: [CatalogProblem]
}

public extension HuntingCatalog {
    /// The law lives on Retsinformation. The source link may point nowhere else.
    static let sourceHost = "retsinformation.dk"

    /// Empty means the file is fit to show. A file that decodes can still be broken.
    var problems: [CatalogProblem] {
        var problems: [CatalogProblem] = []
        let species = allSpecies.map(\.id)
        let placeIds = Set(places.map(\.id))

        if species.isEmpty { problems.append(.noSpecies) }
        if !placeIds.contains("dk") { problems.append(.noDenmark) }
        problems += Self.repeated(species).map(CatalogProblem.repeatedSpecies)
        problems += Self.repeated(places.map(\.id)).map(CatalogProblem.repeatedPlace)
        for place in places {
            if let parent = place.parentId, !placeIds.contains(parent) {
                problems.append(.unknownParent(place: place.id, parent: parent))
            }
        }
        let speciesIds = Set(species)
        for override in overrides {
            if !speciesIds.contains(override.speciesId) {
                problems.append(.overrideForUnknownSpecies(override.speciesId))
            }
            if !placeIds.contains(override.placeId) {
                problems.append(.overrideForUnknownPlace(override.placeId))
            }
        }
        if sourceLink == nil { problems.append(.untrustedSource(sourceURL)) }
        return problems
    }

    /// The source as a link, only over https to Retsinformation.
    var sourceLink: URL? {
        guard let url = URL(string: sourceURL),
              url.scheme?.lowercased() == "https",
              url.user == nil,
              let host = url.host()?.lowercased(),
              host == Self.sourceHost || host == "www." + Self.sourceHost
        else { return nil }
        return url
    }

    /// For downloaded and cached files. Throws `CatalogRefused`, so the app keeps the data it has.
    static func decodeChecked(from data: Data) throws -> HuntingCatalog {
        let catalog = try decode(from: data)
        let problems = catalog.problems
        guard problems.isEmpty else { throw CatalogRefused(problems: problems) }
        return catalog
    }

    private static func repeated(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var repeated: [String] = []
        for id in ids where !seen.insert(id).inserted && !repeated.contains(id) {
            repeated.append(id)
        }
        return repeated
    }
}

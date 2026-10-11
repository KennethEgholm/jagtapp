import Foundation

public enum PlaceKind: String, Codable, Sendable, Equatable {
    case country
    case region
    case area
    case island
}

public struct Place: Codable, Sendable, Equatable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var kind: PlaceKind
    public var parentId: String?
    public var matchNames: [String]
    /// Representative point, for sun times. Optional so older data still decodes.
    public var latitude: Double?
    public var longitude: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, kind
        case parentId = "parent_id"
        case matchNames = "match_names"
        case latitude = "lat"
        case longitude = "lon"
    }

    public init(
        id: String,
        name: String,
        kind: PlaceKind,
        parentId: String?,
        matchNames: [String],
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.parentId = parentId
        self.matchNames = matchNames
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct Coordinate: Sendable, Equatable, Hashable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct LocalOverride: Codable, Sendable, Equatable {
    public var speciesId: String
    public var placeId: String
    public var periods: [SeasonPeriod]
    public var note: String?

    enum CodingKeys: String, CodingKey {
        case periods, note
        case speciesId = "species_id"
        case placeId = "place_id"
    }

    public init(speciesId: String, placeId: String, periods: [SeasonPeriod], note: String?) {
        self.speciesId = speciesId
        self.placeId = placeId
        self.periods = periods
        self.note = note
    }
}

public struct ResolvedSpecies: Identifiable, Sendable, Equatable, Hashable {
    public var species: Species
    public var periods: [SeasonPeriod]
    public var note: String?
    /// Place whose local override applies, or nil for the general time.
    public var localPlaceId: String?

    public init(species: Species, periods: [SeasonPeriod], note: String?, localPlaceId: String? = nil) {
        self.species = species
        self.periods = periods
        self.note = note
        self.localPlaceId = localPlaceId
    }

    public var id: String { species.id }
    public var name: String { species.name }
    public var isLocal: Bool { localPlaceId != nil }
    public var generalPeriods: [SeasonPeriod] { species.periods }
}

public struct ResolvedGroup: Identifiable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var species: [ResolvedSpecies]

    public init(id: String, title: String, species: [ResolvedSpecies]) {
        self.id = id
        self.title = title
        self.species = species
    }
}

public extension HuntingCatalog {
    var denmark: Place {
        places.first(where: { $0.id == "dk" })
            ?? Place(id: "dk", name: "Danmark", kind: .country, parentId: nil, matchNames: ["Danmark"])
    }

    func place(id: String) -> Place? {
        places.first(where: { $0.id == id })
    }

    /// The place's own point, else the nearest ancestor's.
    func coordinate(for place: Place) -> Coordinate? {
        for node in ancestry(of: place) {
            if let latitude = node.latitude, let longitude = node.longitude {
                return Coordinate(latitude: latitude, longitude: longitude)
            }
        }
        return nil
    }

    func ancestry(of place: Place) -> [Place] {
        var chain: [Place] = []
        var current: Place? = place
        var seen = Set<String>()
        while let node = current, !seen.contains(node.id) {
            chain.append(node)
            seen.insert(node.id)
            current = node.parentId.flatMap { self.place(id: $0) }
        }
        return chain
    }

    /// Most specific place whose name equals one of the geocoder's names.
    /// Whole names only: "Hals" must not hit "Als", nor "Ry" hit "Strynø".
    func matchPlace(names: [String]) -> Place {
        let needles = Set(names.map(Self.matchKey).filter { !$0.isEmpty })
        guard !needles.isEmpty else { return denmark }

        var best: (place: Place, score: Int)?
        for place in places {
            let keys = ([place.name] + place.matchNames).map(Self.matchKey)
            guard keys.contains(where: needles.contains) else { continue }
            let score = specificity(place.kind)
            if best == nil || score > best!.score {
                best = (place, score)
            }
        }
        return best?.place ?? denmark
    }

    /// Folded, trimmed, without a trailing " Kommune".
    private static func matchKey(_ name: String) -> String {
        var key = name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "da_DK"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if key.hasSuffix(" kommune") {
            key = String(key.dropLast(" kommune".count))
        }
        return key
    }

    func resolved(_ species: Species, at place: Place) -> ResolvedSpecies {
        let ids = ancestry(of: place).map(\.id)
        for placeId in ids {
            if let override = overrides.first(where: { $0.speciesId == species.id && $0.placeId == placeId }) {
                return ResolvedSpecies(
                    species: species,
                    periods: override.periods,
                    // The general note describes the general time. A local time carries its own.
                    note: override.note,
                    localPlaceId: placeId
                )
            }
        }
        return ResolvedSpecies(species: species, periods: species.periods, note: species.note)
    }

    func resolvedSections(at place: Place) -> [ResolvedGroup] {
        groups.map { group in
            ResolvedGroup(
                id: group.id,
                title: group.title,
                species: group.species.map { resolved($0, at: place) }
            )
        }
    }

    func localTimeCount(at placeId: String) -> Int {
        overrides.filter { $0.placeId == placeId }.count
    }

    private func specificity(_ kind: PlaceKind) -> Int {
        switch kind {
        case .island: return 4
        case .area: return 3
        case .region: return 2
        case .country: return 1
        }
    }
}

import Foundation

public struct HuntingCatalog: Codable, Sendable, Equatable {
    public var version: Int
    public var updated: String
    public var sourceName: String
    public var sourceURL: String
    public var groups: [SpeciesGroup]
    public var places: [Place]
    public var overrides: [LocalOverride]

    enum CodingKeys: String, CodingKey {
        case version, updated, groups, places, overrides
        case sourceName = "source_name"
        case sourceURL = "source_url"
    }

    public init(
        version: Int,
        updated: String,
        sourceName: String,
        sourceURL: String,
        groups: [SpeciesGroup],
        places: [Place] = [],
        overrides: [LocalOverride] = []
    ) {
        self.version = version
        self.updated = updated
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.groups = groups
        self.places = places
        self.overrides = overrides
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        updated = try container.decode(String.self, forKey: .updated)
        sourceName = try container.decode(String.self, forKey: .sourceName)
        sourceURL = try container.decode(String.self, forKey: .sourceURL)
        groups = try container.decode([SpeciesGroup].self, forKey: .groups)
        places = try container.decodeIfPresent([Place].self, forKey: .places) ?? []
        overrides = try container.decodeIfPresent([LocalOverride].self, forKey: .overrides) ?? []
    }

    public static func decode(from data: Data) throws -> HuntingCatalog {
        let decoder = JSONDecoder()
        return try decoder.decode(HuntingCatalog.self, from: data)
    }

    public var allSpecies: [Species] {
        groups.flatMap(\.species)
    }
}

public struct SpeciesGroup: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var species: [Species]

    public init(id: String, title: String, species: [Species]) {
        self.id = id
        self.title = title
        self.species = species
    }
}

public struct Species: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var periods: [SeasonPeriod]
    public var note: String?

    public init(id: String, name: String, periods: [SeasonPeriod], note: String?) {
        self.id = id
        self.name = name
        self.periods = periods
        self.note = note
    }
}

public struct SeasonPeriod: Codable, Sendable, Hashable {
    public var from: MonthDay
    public var to: MonthDay

    public init(from: MonthDay, to: MonthDay) {
        self.from = from
        self.to = to
    }
}

public struct MonthDay: Codable, Sendable, Hashable, Comparable {
    public var month: Int
    public var day: Int

    public init(month: Int, day: Int) {
        self.month = month
        self.day = day
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let parsed = MonthDay.parse(raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Ugyldig MM-DD: \(raw)"
            )
        }
        self = parsed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(formatted)
    }

    public var formatted: String {
        String(format: "%02d-%02d", month, day)
    }

    public static func parse(_ raw: String) -> MonthDay? {
        let parts = raw.split(separator: "-")
        guard parts.count == 2,
              let month = Int(parts[0]),
              let day = Int(parts[1]),
              (1...12).contains(month),
              (1...31).contains(day)
        else { return nil }
        return MonthDay(month: month, day: day)
    }

    public static func < (lhs: MonthDay, rhs: MonthDay) -> Bool {
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }
}

import Foundation

/// Biological notes from `App/JagtFokus/Resources/biologi.json`.
/// Display only. Never used to decide whether a species is open.
///
/// Birds: DOF, Danmarks Fugle. Mammals: Arter.dk texts from Miljøstyrelsen,
/// with Lex or Dansk Pattedyratlas where Arter has no life-history text.
/// “Invasiv” only when Styrelsen for Grøn Arealomlægning og Vandmiljø lists
/// the species for year-round regulation. No population estimates.
public struct BiologyCatalog: Codable, Sendable, Equatable {
    public var version: Int
    public var updated: String
    public var taxa: [String: TaxonBiology]
    /// Hunting species id → taxon id. Sex and age classes share one taxon.
    public var species: [String: String]

    public static func decode(from data: Data) throws -> BiologyCatalog {
        try JSONDecoder().decode(BiologyCatalog.self, from: data)
    }

    public func biology(for speciesId: String) -> TaxonBiology? {
        guard let taxonId = species[speciesId] else { return nil }
        return taxa[taxonId]
    }
}

public struct TaxonBiology: Codable, Sendable, Equatable {
    public var latin: String
    public var facts: [BiologyFact]
    public var sources: [BiologySource]
}

public struct BiologyFact: Codable, Sendable, Equatable, Identifiable {
    public var label: String
    public var value: String

    public var id: String { label }
}

public struct BiologySource: Codable, Sendable, Equatable, Identifiable {
    public var name: String
    public var url: String

    public var id: String { url }
}

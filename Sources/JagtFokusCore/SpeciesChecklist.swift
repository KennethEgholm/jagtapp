import Foundation

/// Species the hunter has taken at least once. One id each. Not a count.
public struct SpeciesChecklist: Codable, Sendable, Equatable {
    public var ids: Set<String>

    enum CodingKeys: String, CodingKey {
        case ids
    }

    public init(ids: Set<String> = []) {
        self.ids = ids
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ids = Set(try container.decodeIfPresent([String].self, forKey: .ids) ?? [])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ids.sorted(), forKey: .ids)
    }

    public func contains(_ id: String) -> Bool {
        ids.contains(id)
    }

    public mutating func add(_ id: String) {
        ids.insert(id)
    }

    public mutating func remove(_ id: String) {
        ids.remove(id)
    }

    /// First launch only. Later journal deletions must not empty a saved list.
    public static func seeded(from journal: BagJournal) -> SpeciesChecklist {
        SpeciesChecklist(ids: Set(journal.entries.map(\.speciesId)))
    }

    public static func decode(from data: Data) throws -> SpeciesChecklist {
        try JSONDecoder().decode(SpeciesChecklist.self, from: data)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

public struct SpeciesChecklistFileStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    public func load() -> SpeciesChecklist? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? SpeciesChecklist.decode(from: data)
    }

    public func save(_ list: SpeciesChecklist) throws {
        let folder = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try list.encoded().write(to: fileURL, options: .atomic)
    }
}

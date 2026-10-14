import Foundation

public struct BagEntry: Codable, Sendable, Equatable, Identifiable, Hashable {
    public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date?
    public var date: String
    public var speciesId: String
    public var count: Int
    public var placeId: String?

    enum CodingKeys: String, CodingKey {
        case id, date, count
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case speciesId = "species_id"
        case placeId = "place_id"
    }

    public init(
        id: UUID,
        createdAt: Date,
        updatedAt: Date? = nil,
        date: String,
        speciesId: String,
        count: Int,
        placeId: String?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.date = date
        self.speciesId = speciesId
        self.count = count
        self.placeId = placeId
    }

    public var lastModified: Date {
        updatedAt ?? createdAt
    }
}

public struct BagYearSummary: Sendable, Equatable {
    public var pieces: Int
    public var speciesCount: Int

    public init(pieces: Int, speciesCount: Int) {
        self.pieces = pieces
        self.speciesCount = speciesCount
    }
}

/// Local bag. Syncs only with the user's own iCloud key-value store.
public struct BagJournal: Codable, Sendable, Equatable {
    public var entries: [BagEntry]
    public var deletedIds: Set<UUID>

    enum CodingKeys: String, CodingKey {
        case entries
        case deletedIds = "deleted_ids"
    }

    public init(entries: [BagEntry] = [], deletedIds: Set<UUID> = []) {
        self.entries = entries
        self.deletedIds = deletedIds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entries = try container.decode([BagEntry].self, forKey: .entries)
        deletedIds = try container.decodeIfPresent(Set<UUID>.self, forKey: .deletedIds) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(entries, forKey: .entries)
        if !deletedIds.isEmpty {
            let sorted = deletedIds.sorted { $0.uuidString < $1.uuidString }
            try container.encode(sorted, forKey: .deletedIds)
        }
    }

    public static func decode(from data: Data) throws -> BagJournal {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BagJournal.self, from: data)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// One piece. Date is the calendar day of `on`, not a browsed query date.
    @discardableResult
    public mutating func record(
        speciesId: String,
        on date: Date,
        placeId: String?,
        now: Date,
        calendar: SeasonCalendar
    ) -> BagEntry {
        let entry = BagEntry(
            id: UUID(),
            createdAt: now,
            date: calendar.dayKey(for: date),
            speciesId: speciesId,
            count: 1,
            placeId: placeId
        )
        entries.append(entry)
        return entry
    }

    /// Adds one to the entry. Does not create a new one.
    public mutating func increment(id: UUID, now: Date = Date()) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].count += 1
        entries[index].updatedAt = now
    }

    public mutating func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        deletedIds.insert(id)
    }

    public mutating func update(
        id: UUID,
        date: String,
        count: Int,
        placeId: String?,
        now: Date = Date()
    ) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].date = date
        entries[index].count = max(1, count)
        entries[index].placeId = placeId
        entries[index].updatedAt = now
    }

    /// Merges two journals by entry id without losing entries or resurrecting deletions.
    public func merged(with other: BagJournal) -> BagJournal {
        let allDeleted = deletedIds.union(other.deletedIds)
        var byId: [UUID: BagEntry] = [:]

        for entry in entries where !allDeleted.contains(entry.id) {
            byId[entry.id] = entry
        }
        for entry in other.entries where !allDeleted.contains(entry.id) {
            if let existing = byId[entry.id] {
                if entry.lastModified > existing.lastModified {
                    byId[entry.id] = entry
                }
            } else {
                byId[entry.id] = entry
            }
        }

        let mergedEntries = byId.values.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return BagJournal(entries: mergedEntries, deletedIds: allDeleted)
    }

    public func entries(inHuntingYear startYear: Int, calendar: SeasonCalendar) -> [BagEntry] {
        entries
            .filter { entry in
                guard let date = calendar.date(fromDayKey: entry.date) else { return false }
                return calendar.huntingYear(on: date) == startYear
            }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date > rhs.date }
                return lhs.createdAt > rhs.createdAt
            }
    }

    public func summary(inHuntingYear startYear: Int, calendar: SeasonCalendar) -> BagYearSummary {
        let rows = entries(inHuntingYear: startYear, calendar: calendar)
        return BagYearSummary(
            pieces: rows.reduce(0) { $0 + $1.count },
            speciesCount: Set(rows.map(\.speciesId)).count
        )
    }

    /// Newest first, one id per species.
    public func recentSpeciesIds(limit: Int = 8) -> [String] {
        var seen = Set<String>()
        var ids: [String] = []
        for entry in entries.sorted(by: { $0.createdAt > $1.createdAt }) {
            if seen.insert(entry.speciesId).inserted {
                ids.append(entry.speciesId)
                if ids.count == limit { break }
            }
        }
        return ids
    }
}

public protocol BagCloudStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
    @discardableResult
    func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: BagCloudStore {}

/// Safe local storage with rolling backup and corrupt-file preservation.
public struct BagFileStore: Sendable {
    public let fileURL: URL
    public let backupURL: URL
    public let corruptURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
        let base = fileURL.deletingPathExtension()
        self.backupURL = base.appendingPathExtension("backup.json")
        self.corruptURL = base.appendingPathExtension("corrupt.json")
    }

    public func load() -> BagJournal {
        let fm = FileManager.default
        if fm.fileExists(atPath: fileURL.path) {
            if let data = try? Data(contentsOf: fileURL),
               let journal = try? BagJournal.decode(from: data) {
                return journal
            }
            preserveCorruptFile()
        }

        if let backupData = try? Data(contentsOf: backupURL),
           let backupJournal = try? BagJournal.decode(from: backupData) {
            try? backupData.write(to: fileURL, options: .atomic)
            return backupJournal
        }

        return BagJournal()
    }

    public func save(_ journal: BagJournal) throws {
        let fm = FileManager.default
        let folder = fileURL.deletingLastPathComponent()
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        if fm.fileExists(atPath: fileURL.path) {
            if let existingData = try? Data(contentsOf: fileURL),
               (try? BagJournal.decode(from: existingData)) != nil {
                try? existingData.write(to: backupURL, options: .atomic)
            } else {
                preserveCorruptFile()
            }
        }

        let data = try journal.encoded()
        try data.write(to: fileURL, options: .atomic)
    }

    private func preserveCorruptFile() {
        guard let raw = try? Data(contentsOf: fileURL) else { return }
        try? raw.write(to: corruptURL, options: .atomic)
    }
}

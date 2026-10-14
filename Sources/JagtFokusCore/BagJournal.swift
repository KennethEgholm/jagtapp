import Foundation

public struct BagEntry: Codable, Sendable, Equatable, Identifiable, Hashable {
    public var id: UUID
    public var createdAt: Date
    public var date: String
    public var speciesId: String
    public var count: Int
    public var placeId: String?

    enum CodingKeys: String, CodingKey {
        case id, date, count
        case createdAt = "created_at"
        case speciesId = "species_id"
        case placeId = "place_id"
    }

    public init(
        id: UUID,
        createdAt: Date,
        date: String,
        speciesId: String,
        count: Int,
        placeId: String?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.date = date
        self.speciesId = speciesId
        self.count = count
        self.placeId = placeId
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

/// Local bag. Not a report, and not sent anywhere.
public struct BagJournal: Codable, Sendable, Equatable {
    public var entries: [BagEntry]

    public init(entries: [BagEntry] = []) {
        self.entries = entries
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
    public mutating func increment(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].count += 1
    }

    public mutating func remove(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    public mutating func update(
        id: UUID,
        date: String,
        count: Int,
        placeId: String?
    ) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].date = date
        entries[index].count = max(1, count)
        entries[index].placeId = placeId
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

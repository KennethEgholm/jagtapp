import Foundation

/// The lists on Jagtbart and the journal. Views only format them.
public extension SeasonCalendar {
    /// Each group with only the species that are open on the day. Groups with none drop out.
    func openGroups(_ groups: [ResolvedGroup], on date: Date) -> [ResolvedGroup] {
        groups.compactMap { group in
            let open = group.species.filter { status(of: $0.periods, on: date).isOpen }
            return open.isEmpty ? nil : ResolvedGroup(id: group.id, title: group.title, species: open)
        }
    }

    /// Species closed on the day, soonest opening first. No season at all goes last. Ties by name.
    func closedSpecies(_ groups: [ResolvedGroup], on date: Date) -> [ResolvedSpecies] {
        let closed = groups.flatMap(\.species).compactMap { item -> (item: ResolvedSpecies, days: Int)? in
            let status = status(of: item.periods, on: date)
            return status.isOpen ? nil : (item, status.daysUntilOpening ?? .max)
        }
        return closed
            .sorted { lhs, rhs in
                lhs.days == rhs.days ? lhs.item.name < rhs.item.name : lhs.days < rhs.days
            }
            .map(\.item)
    }

    /// Open species whose last day is within a week.
    func closingSoonCount(_ groups: [ResolvedGroup], on date: Date) -> Int {
        groups.flatMap(\.species).filter { status(of: $0.periods, on: date).isClosingSoon }.count
    }
}

/// Search in species and place names. The names are Danish in both app languages.
public enum TextSearch {
    /// Ignores case and accents, so "gragas" finds "Grågås". An empty query matches everything.
    public static func matches(_ text: String, query: String) -> Bool {
        let needle = fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return needle.isEmpty || fold(text).contains(needle)
    }

    /// One of several names, e.g. a place and its other names.
    public static func matches(any texts: [String], query: String) -> Bool {
        texts.contains { matches($0, query: query) }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "da_DK"))
    }
}

import Foundation
import Observation

/// Local bag file. The core stays free of file I/O.
@MainActor
@Observable
final class BagStore {
    private(set) var journal: BagJournal
    /// Entry the confirmation refers to.
    private(set) var pendingId: UUID?
    /// Bumped on a successful record. Drives haptics.
    private(set) var saves = 0
    /// Bumped when a swipe action records from another tab.
    private(set) var tabRequests = 0
    let draft = BagDraft()

    private let fileURL: URL
    private let calendar = SeasonCalendar()

    init(fileURL: URL? = nil) {
        let url = fileURL ?? Self.defaultURL
        self.fileURL = url
        journal = Self.load(from: url)
    }

    var pending: BagEntry? {
        guard let pendingId else { return nil }
        return journal.entries.first { $0.id == pendingId }
    }

    @discardableResult
    func record(speciesId: String, on date: Date, placeId: String?) -> BagEntry {
        let now = Date()
        let entry = journal.record(speciesId: speciesId, on: date, placeId: placeId, now: now, calendar: calendar)
        pendingId = entry.id
        saves += 1
        save()
        return entry
    }

    @discardableResult
    func recordAndSwitchTab(speciesId: String, in store: SeasonStore) -> BagEntry {
        let entry = record(
            speciesId: speciesId,
            on: draft.date(now: store.now),
            placeId: draft.placeId(in: store)
        )
        tabRequests += 1
        return entry
    }

    func incrementPending() {
        guard let pendingId else { return }
        journal.increment(id: pendingId)
        save()
    }

    func undoPending() {
        guard let pendingId else { return }
        journal.remove(id: pendingId)
        self.pendingId = nil
        save()
    }

    func clearPending() {
        pendingId = nil
    }

    func update(id: UUID, date: Date, count: Int, placeId: String?) {
        journal.update(
            id: id,
            date: calendar.dayKey(for: date),
            count: count,
            placeId: placeId
        )
        save()
    }

    func remove(id: UUID) {
        journal.remove(id: id)
        if pendingId == id { pendingId = nil }
        save()
    }

    func entry(id: UUID) -> BagEntry? {
        journal.entries.first { $0.id == id }
    }

    private func save() {
        do {
            let folder = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try journal.encoded().write(to: fileURL, options: .atomic)
        } catch {
            // The in-memory journal still has the entry. Next launch reloads the last good file.
        }
    }

    private static var defaultURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "vildtudbytte.json")
    }

    private static func load(from url: URL) -> BagJournal {
        guard let data = try? Data(contentsOf: url),
              let journal = try? BagJournal.decode(from: data)
        else { return BagJournal() }
        return journal
    }
}

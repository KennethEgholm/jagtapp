import Foundation
import Observation

/// Local bag file with rolling backup and automatic iCloud key-value sync.
@MainActor
@Observable
final class BagStore {
    static let cloudKey = "vildtudbytte"

    private(set) var journal: BagJournal
    /// Entry the confirmation refers to.
    private(set) var pendingId: UUID?
    /// Bumped on a successful record. Drives haptics.
    private(set) var saves = 0
    /// Bumped when a swipe action records from another tab.
    private(set) var tabRequests = 0
    let draft = BagDraft()

    private let fileStore: BagFileStore
    private let cloud: BagCloudStore?
    private let calendar = SeasonCalendar()
    @ObservationIgnored private var cloudObserver: NSObjectProtocol?

    init(fileURL: URL? = nil, cloud: BagCloudStore? = nil) {
        let url = fileURL ?? Self.defaultURL
        let fileStore = BagFileStore(fileURL: url)
        self.fileStore = fileStore
        self.cloud = cloud ?? (fileURL == nil ? NSUbiquitousKeyValueStore.default : nil)
        journal = fileStore.load()
        syncWithCloud()
        observeCloudChanges()
    }

    deinit {
        if let cloudObserver {
            NotificationCenter.default.removeObserver(cloudObserver)
        }
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

    func syncWithCloud() {
        guard let cloud else { return }
        cloud.synchronize()
        if let cloudData = cloud.data(forKey: Self.cloudKey),
           let cloudJournal = try? BagJournal.decode(from: cloudData) {
            let merged = journal.merged(with: cloudJournal)
            if merged != journal {
                journal = merged
                try? fileStore.save(journal)
            }
            if merged != cloudJournal, let data = try? merged.encoded() {
                cloud.set(data, forKey: Self.cloudKey)
                cloud.synchronize()
            }
        } else if !journal.entries.isEmpty || !journal.deletedIds.isEmpty,
                  let data = try? journal.encoded() {
            cloud.set(data, forKey: Self.cloudKey)
            cloud.synchronize()
        }
    }

    private func save() {
        if let cloud,
           let cloudData = cloud.data(forKey: Self.cloudKey),
           let cloudJournal = try? BagJournal.decode(from: cloudData) {
            journal = journal.merged(with: cloudJournal)
        }
        try? fileStore.save(journal)
        if let cloud, let data = try? journal.encoded() {
            cloud.set(data, forKey: Self.cloudKey)
            cloud.synchronize()
        }
    }

    private func observeCloudChanges() {
        guard let cloud = cloud as? NSUbiquitousKeyValueStore else { return }
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.syncWithCloud()
            }
        }
    }

    private static var defaultURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "vildtudbytte.json")
    }
}

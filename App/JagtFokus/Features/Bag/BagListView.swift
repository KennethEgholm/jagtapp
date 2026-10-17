import SwiftUI

/// The year's bag. Empty means no entries, not "nothing taken".
struct BagListView: View {
    @Environment(SeasonStore.self) private var store
    @Environment(BagStore.self) private var bag

    private var year: Int {
        store.calendar.huntingYear(on: store.now)
    }

    private var rows: [BagEntry] {
        bag.journal.entries(inHuntingYear: year, calendar: store.calendar)
    }

    private var summary: BagYearSummary {
        bag.journal.summary(inHuntingYear: year, calendar: store.calendar)
    }

    private var months: [(id: String, title: String, entries: [BagEntry])] {
        var order: [String] = []
        var grouped: [String: [BagEntry]] = [:]
        for entry in rows {
            let key = String(entry.date.prefix(7))
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(entry)
        }
        return order.map { key in
            let title = store.calendar.monthYear(fromDayKey: grouped[key]?.first?.date ?? "") ?? key
            return (key, title.capitalizedFirst, grouped[key] ?? [])
        }
    }

    var body: some View {
        List {
            Section {
                CountCard(
                    count: summary.pieces,
                    title: summary.pieces == 1 ? String(localized: "stykke") : String(localized: "stykker")
                ) {
                    Text("Jagtåret \(store.calendar.huntingYearLabel(year))")
                        .foregroundStyle(.secondary)
                }
            }

            if rows.isEmpty {
                Section {
                    Text("Ingen poster.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(months, id: \.id) { month in
                    Section(month.title) {
                        ForEach(month.entries) { entry in
                            NavigationLink(value: BagRoute.edit(entry.id)) {
                                BagEntryRow(entry: entry)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                bag.remove(id: month.entries[index].id)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Copy.bagTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BagEntryRow: View {
    @Environment(SeasonStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entry: BagEntry

    private var name: String {
        store.catalog.allSpecies.first { $0.id == entry.speciesId }?.name ?? entry.speciesId
    }

    private var placeName: String? {
        entry.placeId.flatMap { store.catalog.place(id: $0)?.name }
    }

    private var dateText: String {
        guard let date = store.calendar.date(fromDayKey: entry.date) else { return entry.date }
        return store.calendar.shortWithYear(date)
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.s))
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            layout {
                Text(name)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(entry.count)")
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            meta
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var meta: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xxs))
            : AnyLayout(HStackLayout(spacing: Spacing.xs))
        layout {
            Text(dateText)
            if let placeName {
                Text(placeName)
            }
        }
    }
}

struct BagEditView: View {
    @Environment(SeasonStore.self) private var store
    @Environment(BagStore.self) private var bag
    @Environment(\.dismiss) private var dismiss
    let id: UUID

    @State private var date = Date()
    @State private var count = 1
    @State private var placeId: String?
    @State private var loaded = false

    var body: some View {
        Form {
            if bag.entry(id: id) == nil {
                Text("Posten er slettet.")
                    .foregroundStyle(.secondary)
            } else {
                DatePicker("Dato", selection: $date, displayedComponents: .date)
                    .environment(\.calendar, store.calendar.calendar)
                    .environment(\.timeZone, store.calendar.calendar.timeZone)

                Stepper(value: $count, in: 1...999) {
                    Text("Antal \(count)")
                        .monospacedDigit()
                }

                Picker("Sted", selection: $placeId) {
                    Text("Intet sted").tag(String?.none)
                    ForEach(store.catalog.places) { place in
                        Text(place.name).tag(Optional(place.id))
                    }
                }

                Button("Slet", role: .destructive) {
                    bag.remove(id: id)
                    dismiss()
                }
            }
        }
        .navigationTitle("Ret")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onChange(of: date) { _, _ in write() }
        .onChange(of: count) { _, _ in write() }
        .onChange(of: placeId) { _, _ in write() }
    }

    private func load() {
        guard let entry = bag.entry(id: id) else { return }
        date = store.calendar.date(fromDayKey: entry.date) ?? Date()
        count = entry.count
        placeId = entry.placeId
        loaded = true
    }

    private func write() {
        guard loaded else { return }
        bag.update(id: id, date: date, count: count, placeId: placeId)
    }
}

import SwiftUI

/// Date and place for this tab only. Does not change Jagtbar.
@MainActor
@Observable
final class BagDraft {
    var followToday = true
    var pickedDate = Date()
    var followHere = true
    var pickedPlace: Place?
    var choices = 0

    func date(now: Date) -> Date {
        followToday ? now : pickedDate
    }

    func place(in store: SeasonStore) -> Place {
        if followHere, store.locationState == .found, let gps = store.gpsPlace { return gps }
        if followHere { return store.catalog.denmark }
        return pickedPlace ?? store.catalog.denmark
    }

    /// Nil while following here and GPS has not landed. A picked place is stored.
    func placeId(in store: SeasonStore) -> String? {
        if followHere {
            guard store.locationState == .found else { return nil }
            return store.gpsPlace?.id
        }
        return pickedPlace?.id
    }

    func select(date: Date, now: Date, calendar: Calendar) {
        choices += 1
        if calendar.isDate(date, inSameDayAs: now) {
            followToday = true
            pickedDate = now
        } else {
            followToday = false
            pickedDate = date
        }
    }

    func useHere() {
        choices += 1
        followHere = true
    }

    func select(place: Place) {
        choices += 1
        followHere = false
        pickedPlace = place
    }
}

/// The Nedlagt tab. One tap on a species records it. Date and place stay on this tab.
struct BagTabView: View {
    @Environment(SeasonStore.self) private var store
    @Environment(BagStore.self) private var bag
    @State private var path: [BagRoute] = []
    @State private var showDate = false
    @State private var showPlace = false

    private var draft: BagDraft { bag.draft }

    private var bagDate: Date { draft.date(now: store.now) }

    private var isBagToday: Bool {
        store.calendar.calendar.isDate(bagDate, inSameDayAs: store.now)
    }

    /// Open for this tab's date and place, not Jagtbar's query.
    private var openHere: [ResolvedSpecies] {
        let sections = store.catalog.resolvedSections(at: draft.place(in: store))
        return store.calendar.openGroups(sections, on: bagDate).flatMap(\.species)
    }

    /// Recent only if still open for this date and place. Closed species stay in search.
    private var recent: [ResolvedSpecies] {
        let openIds = Dictionary(uniqueKeysWithValues: openHere.map { ($0.id, $0) })
        return bag.journal.recentSpeciesIds().compactMap { openIds[$0] }
    }

    private var rest: [ResolvedSpecies] {
        let recentIds = Set(recent.map(\.id))
        return openHere.filter { !recentIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                yearRow
                DatePlaceRows(
                    date: bagDate,
                    place: draft.place(in: store),
                    followsHere: draft.followHere,
                    showDate: $showDate,
                    showPlace: $showPlace
                )

                if !recent.isEmpty {
                    Section("Senest nedlagt") {
                        ForEach(recent) { species in
                            recordButton(id: species.id, name: species.name)
                        }
                    }
                }

                Section(isBagToday ? String(localized: "Jagtbart i dag") : String(localized: "Jagtbart")) {
                    if rest.isEmpty {
                        Text(isBagToday ? String(localized: "Intet jagtbart i dag.") : String(localized: "Intet jagtbart."))
                            .font(.body)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(rest) { item in
                            recordButton(id: item.id, name: item.name)
                        }
                    }
                }

                Section {
                    Button {
                        path.append(.search)
                    } label: {
                        Label("Søg i alle arter", systemImage: "magnifyingglass")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .tint(.primary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Copy.bagHeading)
            .navigationDestination(for: BagRoute.self) { route in
                switch route {
                case .search:
                    BagSearchView(draft: draft) { path.removeAll() }
                case .list:
                    BagListView()
                case .speciesList:
                    SpeciesListView()
                case .edit(let id):
                    BagEditView(id: id)
                }
            }
            .sheet(isPresented: $showDate) {
                DatePickerSheet(initialDate: bagDate) { picked in
                    draft.select(date: picked, now: store.now, calendar: store.calendar.calendar)
                }
            }
            .sheet(isPresented: $showPlace) {
                PlacePickerView(
                    followHere: draft.followHere,
                    selectedPlaceId: draft.place(in: store).id,
                    onHere: {
                        draft.useHere()
                        store.locate()
                    },
                    onSelect: { draft.select(place: $0) }
                )
            }
            .safeAreaInset(edge: .bottom) {
                if path.isEmpty, let entry = bag.pending, let name = speciesName(entry.speciesId) {
                    confirmation(name: name, count: entry.count)
                }
            }
            .sensoryFeedback(.selection, trigger: draft.choices)
            .onChange(of: bag.tabRequests) { _, _ in
                path.removeAll()
            }
            .onAppear { store.locate() }
        }
    }

    private var yearSummary: BagYearSummary {
        let year = store.calendar.huntingYear(on: store.now)
        return bag.journal.summary(inHuntingYear: year, calendar: store.calendar)
    }

    private var yearRow: some View {
        let year = store.calendar.huntingYear(on: store.now)
        let pieces = yearSummary.pieces
        let value = pieces == 0 ? String(localized: "Ingen poster") : Copy.pieces(pieces)
        return Section {
            Button {
                bag.clearPending()
                path.append(.list)
            } label: {
                QueryRow(
                    systemImage: "list.bullet.clipboard",
                    title: Copy.bagYearRow,
                    value: value,
                    detail: store.calendar.huntingYearLabel(year)
                )
            }
            .tint(.primary)
            .accessibilityHint("Vis årets poster")

            Button {
                bag.clearPending()
                path.append(.speciesList)
            } label: {
                QueryRow(
                    systemImage: "checklist",
                    title: Copy.speciesListTitle,
                    value: speciesListValue,
                    detail: nil
                )
            }
            .tint(.primary)
            .accessibilityHint("Vis arter du har nedlagt")
        }
    }

    private var speciesListValue: String {
        let count = bag.speciesList.ids.count
        return count == 0 ? String(localized: "Ingen arter") : Copy.speciesCount(count)
    }

    private func recordButton(id: String, name: String) -> some View {
        Button {
            record(id)
        } label: {
            HStack(alignment: .center, spacing: Spacing.s) {
                Text(name)
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .tint(.primary)
        .accessibilityLabel("Notér \(name)")
    }

    private func record(_ speciesId: String) {
        bag.record(speciesId: speciesId, on: bagDate, placeId: draft.placeId(in: store))
    }

    private func confirmation(name: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text("\(name) noteret")
                    .font(.title2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.xs)
                Button {
                    bag.clearPending()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .tint(.secondary)
                .accessibilityLabel("Luk bekræftelse")
            }
            Text(Copy.pieces(count))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.s) { confirmationButtons }
                VStack(alignment: .leading, spacing: Spacing.xs) { confirmationButtons }
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var confirmationButtons: some View {
        Button("Fortryd", role: .destructive) {
            bag.undoPending()
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        Button("+1") {
            bag.incrementPending()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        Button("Se året") {
            bag.clearPending()
            path.append(.list)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func speciesName(_ id: String) -> String? {
        store.catalog.allSpecies.first { $0.id == id }?.name
    }
}

enum BagRoute: Hashable {
    case search
    case list
    case speciesList
    case edit(UUID)
}

/// Escape hatch. Keyboard only after the hunter asks for search.
struct BagSearchView: View {
    @Environment(SeasonStore.self) private var store
    @Environment(BagStore.self) private var bag
    var draft: BagDraft
    var onRecorded: () -> Void
    @State private var query = ""

    private var species: [Species] {
        store.catalog.allSpecies.filter { TextSearch.matches($0.name, query: query) }
    }

    var body: some View {
        List {
            ForEach(species) { item in
                Button {
                    bag.record(
                        speciesId: item.id,
                        on: draft.date(now: store.now),
                        placeId: draft.placeId(in: store)
                    )
                    onRecorded()
                } label: {
                    Text(item.name)
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .tint(.primary)
                .accessibilityLabel("Notér \(item.name)")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Søg")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Art")
    }
}

/// Trailing swipe action on species rows in Jagtbar and Alle arter.
private struct BagSwipeModifier: ViewModifier {
    @Environment(SeasonStore.self) private var store
    @Environment(BagStore.self) private var bag
    let speciesId: String

    func body(content: Content) -> some View {
        content.swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                bag.recordAndSwitchTab(speciesId: speciesId, in: store)
            } label: {
                Label(Copy.bagTab, systemImage: "plus.circle")
            }
            .tint(Color.seasonOpen)
        }
    }
}

extension View {
    func bagSwipeAction(speciesId: String) -> some View {
        modifier(BagSwipeModifier(speciesId: speciesId))
    }
}

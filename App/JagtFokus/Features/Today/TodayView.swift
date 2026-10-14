import SwiftUI

struct TodayView: View {
    @Environment(SeasonStore.self) private var store
    @State private var showsClosed = false
    @State private var path: [SpeciesRoute] = []
    @State private var showDate = false
    @State private var showPlace = false

    var body: some View {
        NavigationStack(path: $path) {
            let sections = store.resolvedSections
            let open = openGroups(sections)
            let closed = closedItems(sections)

            List {
                Section {
                    ListHeading(title: Copy.headline)
                }
                .listSectionSpacing(.compact)

                QueryRows(showDate: $showDate, showPlace: $showPlace)

                Section {
                    AnswerCard(
                        openCount: open.reduce(0) { $0 + $1.species.count },
                        closingSoon: open.flatMap(\.species).filter { store.status(of: $0).isClosingSoon }.count,
                        nextOpening: closed.first
                    )
                }

                ForEach(open) { group in
                    Section(group.title) {
                        ForEach(group.species) { item in
                            NavigationLink(value: SpeciesRoute(speciesId: item.id, context: .query)) {
                                SpeciesRow(item: item, context: .query)
                            }
                            .bagSwipeAction(speciesId: item.id)
                        }
                    }
                }

                if !closed.isEmpty {
                    Section {
                        if open.isEmpty {
                            closedHeader(count: closed.count, chevron: nil)
                        } else {
                            Button {
                                withAnimation { showsClosed.toggle() }
                            } label: {
                                closedHeader(count: closed.count, chevron: showsClosed)
                            }
                            .tint(.primary)
                            .accessibilityValue(showsClosed ? "Vist" : "Skjult")
                            .accessibilityHint("Viser arter uden jagttid lige nu, sorteret efter næste åbning")
                        }

                        if closedExpanded(open) {
                            ForEach(closed) { item in
                                NavigationLink(value: SpeciesRoute(speciesId: item.id, context: .query)) {
                                    SpeciesRow(item: item, context: .query)
                                }
                                .bagSwipeAction(speciesId: item.id)
                            }
                        }
                    } footer: {
                        Text("Sorteret efter næste åbning.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .contentMargins(.top, Spacing.xs, for: .scrollContent)
            .refreshable { await store.refresh() }
            .scrollRevealedTitle("Jagtbar")
            .navigationDestination(for: SpeciesRoute.self) { route in
                SpeciesDetailView(route: route)
            }
            .sheet(isPresented: $showDate) {
                DatePickerSheet(initialDate: store.queryDate) { store.select(date: $0) }
            }
            .sheet(isPresented: $showPlace) {
                PlacePickerView(
                    followHere: store.followHere,
                    selectedPlaceId: store.pickedPlace.id,
                    onHere: { store.useHere() },
                    onSelect: { store.select(place: $0) }
                )
            }
            .sensoryFeedback(.selection, trigger: store.userSelections)
            .onAppear {
                store.requestLocationIfNeeded()
                applyLaunchRoute()
            }
        }
    }

    /// Debug only: `-species raabuk` opens a detail, `-closed YES` expands the closed section,
    /// `-sheet date|place` opens a picker.
    private func applyLaunchRoute() {
        #if DEBUG
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: "species"), path.isEmpty {
            path = [SpeciesRoute(speciesId: id, context: .query)]
        }
        if defaults.bool(forKey: "closed") { showsClosed = true }
        switch defaults.string(forKey: "sheet") {
        case "date": showDate = true
        case "place": showPlace = true
        default: break
        }
        #endif
    }

    private func openGroups(_ sections: [ResolvedGroup]) -> [ResolvedGroup] {
        sections.compactMap { group in
            let open = group.species.filter { store.status(of: $0).isOpen }
            return open.isEmpty ? nil : ResolvedGroup(id: group.id, title: group.title, species: open)
        }
    }

    /// Closed here and now, soonest opening first. No season at all goes last.
    private func closedItems(_ sections: [ResolvedGroup]) -> [ResolvedSpecies] {
        sections.flatMap(\.species)
            .filter { !store.status(of: $0).isOpen }
            .sorted { lhs, rhs in
                let l = store.status(of: lhs).daysUntilOpening ?? .max
                let r = store.status(of: rhs).daysUntilOpening ?? .max
                return l == r ? lhs.name < rhs.name : l < r
            }
    }

    private func closedHeader(count: Int, chevron expanded: Bool?) -> some View {
        HStack {
            Label("Ikke jagtbar her", systemImage: "moon.zzz")
                .foregroundStyle(.primary)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if let expanded {
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }

    /// Nothing open: show closed species without the extra tap.
    private func closedExpanded(_ open: [ResolvedGroup]) -> Bool {
        showsClosed || open.isEmpty
    }
}

/// The answer, in one glance: how many species are open.
struct AnswerCard: View {
    @Environment(SeasonStore.self) private var store
    let openCount: Int
    let closingSoon: Int
    let nextOpening: ResolvedSpecies?

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            Text("\(openCount)")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(openCount > 0 ? Color.seasonOpen : Color.secondary)
                .contentTransition(.numericText())
                .frame(minWidth: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(openCount == 1 ? "art er jagtbar" : "arter er jagtbare")
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(closingSoon > 0 ? Color.seasonClosingSoon : Color.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.xxs)
        .listRowBackground(Color.seasonOpen.opacity(openCount > 0 ? 0.12 : 0.05))
        .animation(.snappy, value: openCount)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        if openCount == 0 {
            if let nextOpening, let date = store.status(of: nextOpening).nextOpening {
                return "Næste: \(nextOpening.name), \(store.calendar.danish(store.calendar.monthDay(on: date)))"
            }
            return "Vælg en anden dag eller et andet sted."
        }
        if closingSoon == 1 { return "1 har sidste dag inden for en uge" }
        if closingSoon > 1 { return "\(closingSoon) har sidste dag inden for en uge" }
        return store.isQueryToday ? "i dag, \(store.queryPlace.name)" : "\(store.calendar.danish(store.calendar.monthDay(on: store.queryDate))), \(store.queryPlace.name)"
    }
}

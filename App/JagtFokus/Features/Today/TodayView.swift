import SwiftUI

struct TodayView: View {
    @Environment(SeasonStore.self) private var store
    @State private var showsClosed = false
    /// Open-group ids the user has opened. Starts empty: every category is collapsed.
    @State private var expanded: Set<String> = []
    @State private var path: [SpeciesRoute] = []
    @State private var showDate = false
    @State private var showPlace = false
    @State private var showSchweiss = false
    #if DEBUG
    /// `-open vejr` pushes the weather page straight away, for screenshots.
    @State private var debugWeather = false
    #endif
    @AppStorage(Copy.collapseGroupsKey) private var collapseGroups = true

    var body: some View {
        NavigationStack(path: $path) {
            let sections = store.resolvedSections
            let open = store.calendar.openGroups(sections, on: store.queryDate)
            let closed = store.calendar.closedSpecies(sections, on: store.queryDate)

            List {
                Section {
                    ListHeading(title: Copy.headline)
                }
                .listSectionSpacing(.compact)

                DatePlaceRows(
                    date: store.queryDate,
                    place: store.queryPlace,
                    followsHere: store.followHere,
                    showDate: $showDate,
                    showPlace: $showPlace
                )

                // The answer right under the question. The sun is display only, so it comes after.
                Section {
                    AnswerCard(
                        openCount: open.reduce(0) { $0 + $1.species.count },
                        closingSoon: store.calendar.closingSoonCount(open, on: store.queryDate),
                        nextOpening: closed.first
                    )
                }

                QuerySunSection()

                ForEach(open) { group in
                    Section {
                        if collapseGroups {
                            FoldButton(expanded: expanded.contains(group.id), hint: "Viser arterne i gruppen") {
                                expanded.toggle(group.id)
                            } label: {
                                GroupHeader(group: group, expanded: expanded.contains(group.id), closingSoon: closingSoon(group))
                            }
                            if expanded.contains(group.id) {
                                openLinks(group)
                            }
                        } else {
                            GroupHeader(group: group, closingSoon: closingSoon(group))
                            openLinks(group)
                        }
                    }
                }

                if !closed.isEmpty {
                    Section {
                        if open.isEmpty {
                            closedHeader(count: closed.count, expanded: nil)
                        } else {
                            FoldButton(expanded: showsClosed, hint: "Viser arter uden jagttid lige nu, sorteret efter næste åbning") {
                                showsClosed.toggle()
                            } label: {
                                closedHeader(count: closed.count, expanded: showsClosed)
                            }
                        }

                        // Nothing open: show closed species without the extra tap.
                        if showsClosed || open.isEmpty {
                            ForEach(closed) { item in
                                speciesLink(item)
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
            .scrollRevealedTitle(Copy.todayTab)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(Copy.schweissToolbar) { showSchweiss = true }
                        .tint(.primary)
                        .accessibilityHint("Åbn Schweiss-registret")
                }
            }
            .navigationDestination(for: SpeciesRoute.self) { route in
                SpeciesDetailView(route: route)
            }
            #if DEBUG
            .navigationDestination(isPresented: $debugWeather) {
                WeatherView()
            }
            #endif
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
            .sheet(isPresented: $showSchweiss) {
                SchweissSheet()
            }
            .sensoryFeedback(.selection, trigger: store.userSelections)
            .onAppear {
                store.requestLocationIfNeeded()
                applyLaunchRoute()
            }
        }
    }

    /// Debug only: `-species raabuk` opens a detail, `-closed YES` expands the closed section,
    /// `-groups open` expands every open group, `-sheet date|place|schweiss` opens a picker or the
    /// Schweiss page, `-open vejr` pushes the weather page.
    private func applyLaunchRoute() {
        #if DEBUG
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: "species"), path.isEmpty {
            path = [SpeciesRoute(speciesId: id, context: .query)]
        }
        if defaults.bool(forKey: "closed") { showsClosed = true }
        if GroupFolding.launchOpensAll {
            expanded = Set(store.calendar.openGroups(store.resolvedSections, on: store.queryDate).map(\.id))
        }
        switch defaults.string(forKey: "sheet") {
        case "date": showDate = true
        case "place": showPlace = true
        case "schweiss": showSchweiss = true
        default: break
        }
        if defaults.string(forKey: "open") == "vejr" { debugWeather = true }
        #endif
    }

    private func closingSoon(_ group: ResolvedGroup) -> Int {
        store.calendar.closingSoonCount([group], on: store.queryDate)
    }

    @ViewBuilder
    private func openLinks(_ group: ResolvedGroup) -> some View {
        ForEach(group.species) { item in
            speciesLink(item)
        }
    }

    private func speciesLink(_ item: ResolvedSpecies) -> some View {
        NavigationLink(value: SpeciesRoute(speciesId: item.id, context: .query)) {
            SpeciesRow(item: item, context: .query)
        }
        .bagSwipeAction(speciesId: item.id)
    }

    private func closedHeader(count: Int, expanded: Bool?) -> some View {
        HStack {
            Label("Ikke jagtbar her", systemImage: "moon.zzz")
                .foregroundStyle(.primary)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if let expanded {
                FoldChevron(expanded: expanded)
            }
        }
        .contentShape(Rectangle())
    }
}

/// The answer, in one glance: how many species are open.
struct AnswerCard: View {
    @Environment(SeasonStore.self) private var store
    let openCount: Int
    let closingSoon: Int
    let nextOpening: ResolvedSpecies?

    var body: some View {
        CountCard(
            count: openCount,
            title: openCount == 1 ? String(localized: "art er jagtbar") : String(localized: "arter er jagtbare")
        ) {
            if closingSoon > 0 {
                // Inline, so the icon stays on the first line when the text wraps.
                Text("\(Image(systemName: "hourglass")) \(subtitle)")
                    .foregroundStyle(.seasonClosingSoon)
            } else {
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var subtitle: String {
        if openCount == 0 {
            if let nextOpening, let date = store.status(of: nextOpening).nextOpening {
                return String(localized: "Næste: \(nextOpening.name), \(store.calendar.short(store.calendar.monthDay(on: date)))")
            }
            return String(localized: "Vælg en anden dag eller et andet sted.")
        }
        if closingSoon > 0 { return Copy.closingSoon(closingSoon) }
        return store.isQueryToday
            ? String(localized: "i dag, \(store.queryPlace.name)")
            : String(localized: "\(store.calendar.short(store.calendar.monthDay(on: store.queryDate))), \(store.queryPlace.name)")
    }
}

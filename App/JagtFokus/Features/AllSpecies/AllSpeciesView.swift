import SwiftUI

/// General times for every species. No date, no place, no status.
struct AllSpeciesView: View {
    @Environment(SeasonStore.self) private var store
    @State private var query = ""
    @State private var isSearching = false
    /// Group ids the user has opened. Starts empty: every category is collapsed.
    @State private var expanded: Set<String> = []
    @AppStorage(Copy.collapseGroupsKey) private var collapseGroups = true

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section {
                        Label {
                            Text("Generelle jagttider i Danmark. Lokale tider kan afvige. Se dem under Jagtbart.")
                        } icon: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.tint)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                ForEach(groups) { group in
                    Section {
                        // Search opens the groups with hits, without the extra tap.
                        if collapseGroups && !searching {
                            FoldButton(expanded: expanded.contains(group.id), hint: "Viser arterne i gruppen") {
                                expanded.toggle(group.id)
                            } label: {
                                GroupHeader(group: group, expanded: expanded.contains(group.id))
                            }
                            if expanded.contains(group.id) {
                                speciesLinks(group)
                            }
                        } else {
                            GroupHeader(group: group)
                            speciesLinks(group)
                        }
                    }
                }

                if groups.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, isPresented: $isSearching, prompt: "Søg art")
            .onAppear(perform: applyLaunchSearch)
            .navigationTitle("Alle arter")
            .navigationDestination(for: SpeciesRoute.self) { route in
                SpeciesDetailView(route: route)
            }
        }
    }

    /// Debug only: `-search ræv` opens search with that text. `-groups open` expands every group.
    private func applyLaunchSearch() {
        #if DEBUG
        if let text = UserDefaults.standard.string(forKey: "search"), query.isEmpty {
            isSearching = true
            query = text
        }
        if GroupFolding.launchOpensAll {
            expanded = Set(groups.map(\.id))
        }
        #endif
    }

    private var searching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private func speciesLinks(_ group: ResolvedGroup) -> some View {
        ForEach(group.species) { item in
            NavigationLink(value: SpeciesRoute(speciesId: item.id, context: .general)) {
                SpeciesRow(item: item, context: .general)
            }
            .bagSwipeAction(speciesId: item.id)
        }
    }

    /// General periods only: resolved at Danmark, so no override leaks in.
    private var groups: [ResolvedGroup] {
        let all = store.catalog.resolvedSections(at: store.catalog.denmark)
        guard searching else { return all }
        return all.compactMap { group in
            let hits = group.species.filter { TextSearch.matches($0.name, query: query) }
            return hits.isEmpty ? nil : ResolvedGroup(id: group.id, title: group.title, species: hits)
        }
    }
}

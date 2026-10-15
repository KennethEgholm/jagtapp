import SwiftUI

/// General times for every species. No date, no place, no status.
struct AllSpeciesView: View {
    @Environment(SeasonStore.self) private var store
    @State private var query = ""
    @State private var isSearching = false

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
                        ForEach(group.species) { item in
                            NavigationLink(value: SpeciesRoute(speciesId: item.id, context: .general)) {
                                SpeciesRow(item: item, context: .general)
                            }
                            .bagSwipeAction(speciesId: item.id)
                        }
                    } header: {
                        Text(group.title)
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

    /// Debug only: `-search ræv` opens search with that text.
    private func applyLaunchSearch() {
        #if DEBUG
        if let text = UserDefaults.standard.string(forKey: "search"), query.isEmpty {
            isSearching = true
            query = text
        }
        #endif
    }

    /// General periods only: resolved at Danmark, so no override leaks in.
    private var groups: [ResolvedGroup] {
        let all = store.catalog.resolvedSections(at: store.catalog.denmark)
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return all }
        return all.compactMap { group in
            let hits = group.species.filter { $0.name.localizedStandardContains(needle) }
            return hits.isEmpty ? nil : ResolvedGroup(id: group.id, title: group.title, species: hits)
        }
    }
}

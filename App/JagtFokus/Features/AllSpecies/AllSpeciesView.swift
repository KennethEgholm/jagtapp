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
                    if collapseGroups {
                        Section {
                            if searching {
                                groupHeader(group, shown: true, toggle: false)
                                speciesLinks(group)
                            } else {
                                Button {
                                    withAnimation { toggle(group.id) }
                                } label: {
                                    groupHeader(group, shown: expanded.contains(group.id), toggle: true)
                                }
                                .tint(.primary)
                                .accessibilityValue(expanded.contains(group.id) ? "Vist" : "Skjult")
                                .accessibilityHint("Viser arterne i gruppen")

                                if expanded.contains(group.id) {
                                    speciesLinks(group)
                                }
                            }
                        }
                    } else {
                        Section {
                            groupHeader(group, shown: true, toggle: false)
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
        if Self.launchOpensGroups {
            expanded = Set(groups.map(\.id))
        }
        #endif
    }

    /// Only the current launch. A leftover UserDefaults value from `-groups open` must not keep groups open.
    private static var launchOpensGroups: Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-groups"), index + 1 < args.count else { return false }
        return args[index + 1] == "open"
    }

    private var searching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func toggle(_ id: String) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
        }
    }

    private func groupHeader(_ group: ResolvedGroup, shown: Bool, toggle: Bool) -> some View {
        HStack(spacing: Spacing.xs) {
            GroupSketch(groupId: group.id)
            Text(group.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .layoutPriority(1)
            Spacer(minLength: Spacing.xs)
            Text("\(group.species.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if toggle {
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(shown ? 180 : 0))
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.title), \(group.species.count) arter")
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
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return all }
        return all.compactMap { group in
            let hits = group.species.filter { $0.name.localizedStandardContains(needle) }
            return hits.isEmpty ? nil : ResolvedGroup(id: group.id, title: group.title, species: hits)
        }
    }
}

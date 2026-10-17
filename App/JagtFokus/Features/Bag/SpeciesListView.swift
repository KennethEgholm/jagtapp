import SwiftUI

/// Species taken at least once. Not the year's bag, and not a count.
struct SpeciesListView: View {
    @Environment(SeasonStore.self) private var store
    @Environment(BagStore.self) private var bag
    @State private var showAdd = false

    var body: some View {
        List {
            if groups.isEmpty && unknownIds.isEmpty {
                Section {
                    Text(Copy.speciesListEmpty)
                        .foregroundStyle(.secondary)
                    Button(Copy.speciesListAdd) { showAdd = true }
                        .tint(.primary)
                }
            } else {
                ForEach(groups, id: \.id) { group in
                    Section(Copy.groupTitle(id: group.id, fromData: group.title)) {
                        ForEach(group.species) { species in
                            Text(species.name)
                                .swipeActions {
                                    Button(Copy.speciesListRemove, role: .destructive) {
                                        bag.removeSpecies(species.id)
                                    }
                                }
                        }
                    }
                }
                if !unknownIds.isEmpty {
                    Section("Ukendt") {
                        ForEach(unknownIds, id: \.self) { id in
                            Text(id)
                                .swipeActions {
                                    Button(Copy.speciesListRemove, role: .destructive) {
                                        bag.removeSpecies(id)
                                    }
                                }
                        }
                    }
                }
                Section {
                    Text("Swipe fjerner arten her. Journalen ændres ikke.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(Copy.speciesListTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(Copy.speciesListAdd) { showAdd = true }
            }
        }
        .sheet(isPresented: $showAdd) {
            SpeciesListAddView()
        }
    }

    private var groups: [SpeciesGroup] {
        store.catalog.groups.compactMap { group in
            let species = group.species.filter { bag.speciesList.contains($0.id) }
            guard !species.isEmpty else { return nil }
            return SpeciesGroup(id: group.id, title: group.title, species: species)
        }
    }

    private var unknownIds: [String] {
        let known = Set(store.catalog.allSpecies.map(\.id))
        return bag.speciesList.ids.filter { !known.contains($0) }.sorted()
    }
}

/// Every species, with a check. Searchable. One species, once.
struct SpeciesListAddView: View {
    @Environment(SeasonStore.self) private var store
    @Environment(BagStore.self) private var bag
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if groups.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
                ForEach(groups) { group in
                    Section(Copy.groupTitle(id: group.id, fromData: group.title)) {
                        ForEach(group.species) { species in
                            Button {
                                bag.setSpecies(species.id, included: !bag.speciesList.contains(species.id))
                            } label: {
                                HStack {
                                    Text(species.name)
                                        .foregroundStyle(.primary)
                                    Spacer(minLength: Spacing.xs)
                                    Image(systemName: bag.speciesList.contains(species.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(bag.speciesList.contains(species.id) ? Color.seasonOpen : Color.secondary)
                                        .accessibilityHidden(true)
                                }
                            }
                            .tint(.primary)
                            .accessibilityValue(Copy.selectionState(bag.speciesList.contains(species.id)))
                            .accessibilityHint("Sætter arten på artslisten eller tager den af")
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Søg art")
            .navigationTitle(Copy.speciesListAdd)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Færdig") { dismiss() }
                }
            }
        }
    }

    private var groups: [SpeciesGroup] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.catalog.groups.compactMap { group in
            let species = group.species.filter { species in
                needle.isEmpty || species.name.localizedStandardContains(needle)
            }
            guard !species.isEmpty else { return nil }
            return SpeciesGroup(id: group.id, title: group.title, species: species)
        }
    }
}

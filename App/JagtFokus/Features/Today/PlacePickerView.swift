import SwiftUI

struct PlacePickerView: View {
    @Environment(SeasonStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section {
                        Button {
                            store.useHere()
                            dismiss()
                        } label: {
                            HStack(spacing: Spacing.s) {
                                IconTile(systemImage: "location.fill")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Min position")
                                        .foregroundStyle(.primary)
                                    Text(hereSubtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if store.followHere {
                                    checkmark
                                }
                            }
                        }
                    .tint(.primary)
                    } footer: {
                        Text("Mest specifikke sted gælder: ø før område før region før Danmark.")
                    }
                }

                ForEach(sections, id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.places) { place in
                            Button {
                                store.select(place: place)
                                dismiss()
                            } label: {
                                PlaceRow(
                                    place: place,
                                    parent: store.parentName(of: place),
                                    localCount: store.catalog.localTimeCount(at: place.id),
                                    isSelected: !store.followHere && store.pickedPlace.id == place.id
                                )
                            }
                            .tint(.primary)
                        }
                    }
                }

                if sections.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Søg ø, område eller region")
            .navigationTitle("Vælg sted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Luk") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var checkmark: some View {
        Image(systemName: "checkmark")
            .fontWeight(.semibold)
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel("Valgt")
    }

    private var hereSubtitle: String {
        switch store.locationState {
        case .found: store.gpsPlace?.name ?? "Danmark"
        case .locating: "Finder position…"
        case .denied: "Slået fra i Indstillinger"
        case .unavailable: "Kunne ikke finde position"
        case .idle: "Brug GPS"
        }
    }

    private var filtered: [Place] {
        let places = store.catalog.places
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return places }
        return places.filter { place in
            let hay = ([place.name] + place.matchNames).joined(separator: " ")
            return hay.localizedStandardContains(q)
        }
    }

    private var sections: [(title: String, places: [Place])] {
        let order: [PlaceKind] = [.country, .region, .area, .island]
        return order.compactMap { kind in
            let items = filtered.filter { $0.kind == kind }
            guard !items.isEmpty else { return nil }
            let title: String = switch kind {
            case .country: "Hele landet"
            case .region: "Regioner"
            case .area: "Områder"
            case .island: "Øer"
            }
            return (title, items)
        }
    }
}

private struct PlaceRow: View {
    let place: Place
    let parent: String?
    let localCount: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if localCount > 0 {
                Text(localCount == 1 ? "1 lokal tid" : "\(localCount) lokale tider")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.localTime)
                    .monospacedDigit()
            }
            if isSelected {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("Valgt")
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var subtitle: String? {
        if place.kind == .country { return "Generelle jagttider" }
        return parent
    }
}

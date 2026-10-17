import SwiftUI

struct SpeciesDetailView: View {
    @Environment(SeasonStore.self) private var store
    @Environment(BagStore.self) private var bag
    let route: SpeciesRoute

    var body: some View {
        if let item = store.resolved(speciesId: route.speciesId) {
            content(item)
        } else {
            ContentUnavailableView("Arten findes ikke", systemImage: "questionmark.circle")
        }
    }

    private func content(_ item: ResolvedSpecies) -> some View {
        let isQuery = route.context == .query
        let periods = isQuery ? item.periods : item.generalPeriods
        let note = isQuery ? item.note : item.species.note
        let calendar = store.calendar

        return List {
            Section {
                ListHeading(
                    title: item.name,
                    eyebrow: store.group(of: item.id).map { Copy.groupTitle(id: $0.id, fromData: $0.title) }
                )
            }
            .listSectionSpacing(.compact)

            if let photo = store.photo(for: item.id) {
                Section {
                    SpeciesPhotoView(photo: photo, speciesName: item.name)
                }
                .listSectionSpacing(.compact)
            }

            if isQuery {
                Section {
                    StatusSummary(status: store.status(of: item))
                }
            }

            Section {
                Button {
                    bag.recordAndSwitchTab(speciesId: item.id, in: store)
                } label: {
                    HStack(spacing: Spacing.s) {
                        IconTile(systemImage: "plus.circle.fill")
                        Text(Copy.bagRecord)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .tint(.primary)
            }

            Section {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    SeasonBar(
                        periods: periods,
                        marker: isQuery ? calendar.monthDay(on: store.queryDate) : nil,
                        showsMonths: true,
                        height: 12
                    )
                    .padding(.top, Spacing.xxs)
                    if periods.isEmpty {
                        Text(isQuery ? String(localized: "Ingen jagttid her.") : String(localized: "Ingen generel jagttid."))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(periods.enumerated()), id: \.offset) { _, period in
                            Label {
                                Text("\(calendar.full(period.from)) – \(calendar.full(period.to))")
                                    .monospacedDigit()
                            } icon: {
                                Image(systemName: "calendar")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
                .padding(.vertical, Spacing.xxs)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(calendar.spokenPeriodText(periods))
            } header: {
                Text(isQuery ? String(localized: "Jagttid i \(store.queryPlace.name)") : String(localized: "Generel jagttid"))
            } footer: {
                Text("Jagtåret vist fra 1. april til 31. marts.")
            }

            if isQuery, item.isLocal {
                Section {
                    LabeledContent("Gælder for", value: store.place(id: item.localPlaceId)?.name ?? "")
                    LabeledContent("Generel jagttid") {
                        Text(calendar.periodText(item.generalPeriods))
                            .monospacedDigit()
                    }
                } header: {
                    Text("Lokal jagttid")
                } footer: {
                    Text("Mest specifikke sted gælder: ø før område før region før Danmark.")
                }
            }

            if let note, !note.isEmpty {
                Section("Note") {
                    Text(note)
                }
            }

            if item.species.isRedOrFallowDeer {
                Section {
                    Label(Copy.deerNote, systemImage: "map")
                        .foregroundStyle(.secondary)
                }
            }

            if let biology = store.biology(for: item.id) {
                BiologySection(biology: biology)
            }

            Section {
                if let url = URL(string: store.catalog.sourceURL) {
                    Link(destination: url) {
                        Label("Åbn bekendtgørelsen", systemImage: "arrow.up.right.square")
                    }
                }
            } header: {
                Text("Kilde")
            } footer: {
                Text(Copy.notTheLaw)
            }
        }
        .contentMargins(.top, Spacing.xs, for: .scrollContent)
        .scrollRevealedTitle(item.name)
    }
}

/// Big Jagtbar / Ikke jagtbar block for the selected date and place.
struct StatusSummary: View {
    @Environment(SeasonStore.self) private var store
    let status: SeasonStatus

    var body: some View {
        let calendar = store.calendar
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                Image(systemName: status.isOpen ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(status.isOpen ? Color.seasonOpen : Color.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.isOpen ? String(localized: "Jagtbar") : String(localized: "Ikke jagtbar"))
                        .font(.title2.weight(.bold))
                    Text("\(calendar.longDate(store.queryDate).capitalizedFirst) · \(store.queryPlace.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if status.isOpen, let end = status.endDate, let left = status.daysLeft {
                fact(
                    title: String(localized: "Sidste dag"),
                    value: calendar.longDate(end),
                    detail: StatusCopy.relative(days: left),
                    tint: status.isClosingSoon ? .seasonClosingSoon : .secondary
                )
            } else if let next = status.nextOpening, let days = status.daysUntilOpening {
                fact(
                    title: String(localized: "Åbner"),
                    value: calendar.longDate(next),
                    detail: StatusCopy.relative(days: days),
                    tint: .secondary
                )
            } else {
                Text("Ingen jagttid her i jagtåret.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
    }

    private func fact(title: String, value: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value.capitalizedFirst)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(tint)
            }
            .monospacedDigit()
        }
    }
}

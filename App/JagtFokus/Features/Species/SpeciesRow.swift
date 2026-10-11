import SwiftUI

/// Where a species is shown from. Decides whether status may appear.
enum SpeciesContext: Hashable {
    /// Jagtbar: selected date and place. Shows status.
    case query
    /// Alle arter: general times only. Never status.
    case general
}

struct SpeciesRoute: Hashable {
    let speciesId: String
    let context: SpeciesContext
}

struct SpeciesRow: View {
    @Environment(SeasonStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let item: ResolvedSpecies
    let context: SpeciesContext

    private var status: SeasonStatus? {
        context == .query ? store.status(of: item) : nil
    }

    private var periods: [SeasonPeriod] {
        context == .query ? item.periods : item.generalPeriods
    }

    private var note: String? {
        let text = context == .query ? item.note : item.species.note
        guard let text, !text.isEmpty else { return nil }
        return text
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.xs))

        VStack(alignment: .leading, spacing: Spacing.xxs + 2) {
            layout {
                Text(item.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                if let status {
                    Spacer(minLength: Spacing.xs)
                    SeasonStatusText(status: status, calendar: store.calendar)
                        .font(.subheadline)
                }
            }

            Text(store.calendar.danishPeriodText(periods))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            if context == .general {
                SeasonBar(periods: periods, height: 5)
                    .padding(.vertical, 2)
            }

            if context == .query, item.isLocal {
                LocalBadge()
            }

            if let note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [item.name]
        if let status {
            parts.append(StatusCopy.spoken(status, calendar: store.calendar))
        }
        parts.append(store.calendar.danishSpokenPeriodText(periods))
        if context == .query, item.isLocal {
            parts.append("Lokal jagttid")
        }
        if let note {
            parts.append(note)
        }
        return parts.joined(separator: ". ")
    }
}

import SwiftUI
import UIKit

/// Dato and Sted rows, with any location problem in the footer. Full width, so names never truncate.
/// Jagtbart and Journal each pass their own choice.
struct DatePlaceRows: View {
    @Environment(SeasonStore.self) private var store
    @Environment(\.openURL) private var openURL
    let date: Date
    let place: Place
    /// Following GPS rather than a picked place.
    let followsHere: Bool
    @Binding var showDate: Bool
    @Binding var showPlace: Bool

    var body: some View {
        Section {
            Button { showDate = true } label: {
                QueryRow(
                    systemImage: "calendar",
                    title: String(localized: "Dato"),
                    value: store.calendar.longDate(date).capitalizedFirst,
                    detail: isToday ? String(localized: "I dag") : nil
                )
            }
            .tint(.primary)
            .accessibilityHint("Vælg en anden dag")

            Button { showPlace = true } label: {
                QueryRow(
                    systemImage: followsHere ? "location.fill" : "mappin",
                    title: String(localized: "Sted"),
                    value: place.name,
                    detail: placeDetail,
                    isWorking: followsHere && store.locationState == .locating
                )
            }
            .tint(.primary)
            .accessibilityHint("Vælg et andet sted")
        } footer: {
            if followsHere, let problem = locationProblem {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(problem)
                    if store.locationState == .denied {
                        Button("Åbn Indstillinger-appen") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                        .font(.footnote.weight(.semibold))
                    }
                }
            }
        }
    }

    private var isToday: Bool {
        store.calendar.calendar.isDate(date, inSameDayAs: store.now)
    }

    private var placeDetail: String? {
        guard followsHere else { return nil }
        switch store.locationState {
        case .locating: return String(localized: "Finder position…")
        case .found: return String(localized: "Din position")
        case .denied, .unavailable, .idle: return nil
        }
    }

    /// Says what the row above shows: the last GPS place, or all of Denmark.
    private var locationProblem: String? {
        switch store.locationState {
        case .denied: String(localized: "Position er slået fra. Listen viser hele Danmark. Vælg sted, eller slå position til.")
        case .unavailable:
            if let last = store.gpsPlace, last.id == place.id {
                String(localized: "Kunne ikke opdatere din position. Viser sidst kendte sted: \(last.name).")
            } else {
                String(localized: "Kunne ikke finde din position. Listen viser hele Danmark. Vælg sted.")
            }
        default: nil
        }
    }
}

/// Settings-style row: icon tile, a small title, the value, and a chevron.
struct QueryRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let systemImage: String
    let title: String
    let value: String
    var detail: String?
    var isWorking = false

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        HStack(spacing: Spacing.s) {
            if !stacked {
                IconTile(systemImage: systemImage)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                if stacked {
                    trailing
                }
            }
            Spacer(minLength: Spacing.xs)
            if !stacked {
                trailing
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var trailing: some View {
        if isWorking {
            ProgressView()
        } else if let detail {
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}

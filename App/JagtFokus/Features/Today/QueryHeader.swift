import SwiftUI
import UIKit

/// Date, place and sun rows at the top of Jagtbar. Full width, so names never truncate.
struct QueryRows: View {
    @Environment(SeasonStore.self) private var store
    @Environment(\.openURL) private var openURL
    @Binding var showDate: Bool
    @Binding var showPlace: Bool

    var body: some View {
        Section {
            Button { showDate = true } label: {
                QueryRow(
                    systemImage: "calendar",
                    title: "Dato",
                    value: store.calendar.longDate(store.queryDate).capitalizedFirst,
                    detail: store.isQueryToday ? String(localized: "I dag") : nil
                )
            }
            .tint(.primary)
            .accessibilityHint("Vælg en anden dag")

            Button { showPlace = true } label: {
                QueryRow(
                    systemImage: store.followHere ? "location.fill" : "mappin",
                    title: "Sted",
                    value: store.queryPlace.name,
                    detail: placeDetail,
                    isWorking: store.followHere && store.locationState == .locating
                )
            }
            .tint(.primary)
            .accessibilityHint("Vælg et andet sted")

            if let sun = store.querySun {
                SunRow(
                    calendar: store.calendar,
                    times: sun.times,
                    basis: sunBasis
                )
            }
        } footer: {
            if store.followHere, let problem = locationProblem {
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

    /// Same place and date as the rows above, so the clock times cannot be read as “here”.
    private var sunBasis: String {
        let day = store.calendar.full(store.calendar.monthDay(on: store.queryDate))
        return String(localized: "\(store.queryPlace.name), den \(day)")
    }

    private var placeDetail: String? {
        guard store.followHere else { return nil }
        switch store.locationState {
        case .locating: return String(localized: "Finder position…")
        case .found: return String(localized: "Din position")
        case .denied, .unavailable, .idle: return nil
        }
    }

    private var locationProblem: String? {
        switch store.locationState {
        case .denied: String(localized: "Position er slået fra. Listen viser hele Danmark. Vælg sted, eller slå position til.")
        case .unavailable:
            if let last = store.gpsPlace {
                String(localized: "Kunne ikke opdatere din position. Viser sidst kendte sted: \(last.name).")
            } else {
                String(localized: "Kunne ikke finde din position. Listen viser hele Danmark. Vælg sted.")
            }
        default: nil
        }
    }
}

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

/// Sunrise and sunset for the query. Not tappable. Display only.
struct SunRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let calendar: SeasonCalendar
    let times: SunTimes
    /// What the clock times are for. Always shown, so “here” and a chosen place cannot be confused.
    let basis: String

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        HStack(alignment: .top, spacing: Spacing.s) {
            if !stacked {
                IconTile(systemImage: "sun.horizon.fill", color: .orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Sol")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                let layout = stacked
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xxs))
                    : AnyLayout(HStackLayout(spacing: Spacing.m))
                layout {
                    event(times.sunrise, systemImage: "sunrise.fill")
                    event(times.sunset, systemImage: "sunset.fill")
                }
                .font(.body.weight(.semibold))
                .monospacedDigit()
                Text(basis)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private func event(_ date: Date?, systemImage: String) -> some View {
        Label {
            Text(time(date))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize()
        } icon: {
            // Multicolor draws the arrows white, invisible in light mode.
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange)
        }
    }

    private func time(_ date: Date?) -> String {
        date.map(calendar.clockTime) ?? "–"
    }

    private var spoken: String {
        String(localized: "Solopgang \(time(times.sunrise)), solnedgang \(time(times.sunset)). \(basis)")
    }
}

extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}

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
                    value: store.calendar.danishLongDate(store.queryDate).capitalizedFirst,
                    detail: store.isQueryToday ? "I dag" : nil
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
                SunRow(calendar: store.calendar, times: sun.times, isApproximate: sun.isApproximate)
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
            } else if let sun = store.querySun, sun.isApproximate {
                Text("Soltider for et punkt i \(store.queryPlace.name).")
            }
        }
    }

    private var placeDetail: String? {
        guard store.followHere else { return nil }
        switch store.locationState {
        case .locating: return "Finder position…"
        case .found: return "Din position"
        case .denied, .unavailable, .idle: return nil
        }
    }

    private var locationProblem: String? {
        switch store.locationState {
        case .denied: "Position er slået fra. Listen viser hele Danmark. Vælg sted, eller slå position til."
        case .unavailable:
            if let last = store.gpsPlace {
                "Kunne ikke opdatere din position. Viser sidst kendte sted: \(last.name)."
            } else {
                "Kunne ikke finde din position. Listen viser hele Danmark. Vælg sted."
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
    let isApproximate: Bool

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        HStack(spacing: Spacing.s) {
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
                if stacked, isApproximate {
                    approximate
                }
            }
            Spacer(minLength: Spacing.xs)
            if !stacked, isApproximate {
                approximate
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

    private var approximate: some View {
        Text("ca.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func time(_ date: Date?) -> String {
        date.map(calendar.danishTime) ?? "–"
    }

    private var spoken: String {
        let text = "Solopgang \(time(times.sunrise)), solnedgang \(time(times.sunset))"
        return isApproximate ? text + ", cirka" : text
    }
}

extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}

import SwiftUI

/// Sun times for Jagtbart's date and place, as their own card. Display only.
struct QuerySunSection: View {
    @Environment(SeasonStore.self) private var store

    var body: some View {
        if let sun = store.querySun {
            Section {
                SunRow(calendar: store.calendar, times: sun.times, basis: basis)
            }
        }
    }

    /// Same place and date as the rows above, so the clock times cannot be read as “here”.
    private var basis: String {
        let day = store.calendar.full(store.calendar.monthDay(on: store.queryDate))
        return String(localized: "\(store.queryPlace.name), den \(day)")
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
                IconTile(systemImage: "sun.horizon.fill", color: .sun)
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
                .foregroundStyle(.sun)
        }
    }

    private func time(_ date: Date?) -> String {
        date.map(calendar.clockTime) ?? "–"
    }

    private var spoken: String {
        String(localized: "Solopgang \(time(times.sunrise)), solnedgang \(time(times.sunset)). \(basis)")
    }
}

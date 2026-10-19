import SwiftUI

/// Vejr og måne for Jagtbart's chosen day and place, pushed from the sun card.
/// Weather comes from MET Norway; sun and moon are computed on the phone. Display only.
/// The tiles follow the almanac look: gold label, big value, small note.
struct WeatherView: View {
    @Environment(SeasonStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        List {
            Section {
                Text(basis)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                VStack(alignment: .leading, spacing: Spacing.s) { grids }
            }
            .listRowInsets(EdgeInsets(
                top: Spacing.xxs, leading: Spacing.s, bottom: Spacing.xxs, trailing: Spacing.s
            ))
            .listRowBackground(Color.clear)

            Section {
                Text("Kilde: Meteorologisk institutt (MET). Vejr og måne er kun visning.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, Spacing.xs, for: .scrollContent)
        .navigationTitle(String(localized: "Vejr"))
        .task(id: weatherKey) {
            if let coordinate = store.queryCoordinate?.point {
                await store.weather.load(coordinate: coordinate, on: store.queryDate, calendar: store.calendar)
            }
        }
    }

    /// Same place and date as the rows above, so the numbers cannot be read as "here".
    private var basis: String {
        let day = store.calendar.full(store.calendar.monthDay(on: store.queryDate))
        return Copy.basis(place: store.queryPlace.name, day: day)
    }

    /// One request per place and day: rounded coordinates and the day key.
    private var weatherKey: WeatherStore.Key? {
        store.queryCoordinate.map { WeatherStore.key(for: $0.point, on: store.queryDate, calendar: store.calendar) }
    }

    /// Two grids in a stack: the weather tiles when MET has an answer, then sun and moon.
    @ViewBuilder
    private var grids: some View {
        switch store.weather.state {
        case .loaded(let day):
            Grid(alignment: .leading, horizontalSpacing: Spacing.s, verticalSpacing: Spacing.s) {
                GridRow {
                    tile(String(localized: "Vejret"), systemImage: WeatherSymbols.icon(forSymbolCode: day.symbolCode), value: condition(day))
                    tile(
                        String(localized: "Vind"),
                        arrowDirection: day.windDirection,
                        value: windValue(day),
                        subtitle: day.windDirection.map {
                            String(localized: "fra \(WeatherSymbols.windText(fromDirection: $0))")
                        }
                    )
                }
                GridRow {
                    tile(
                        String(localized: "Temperatur"),
                        systemImage: "thermometer",
                        value: store.isQueryToday
                            ? day.temperature.map({ WeatherSymbols.decimal($0, store.calendar.locale) + "°" })
                            : day.maxTemperature.map({ WeatherSymbols.decimal($0, store.calendar.locale) + "°" }),
                        subtitle: tempRange(day)
                    )
                    tile(
                        String(localized: "Fugtighed"),
                        systemImage: "humidity",
                        value: day.humidity.map { WeatherSymbols.decimal($0, store.calendar.locale, digits: 0...0) + " %" }
                    )
                }
                GridRow {
                    tile(
                        String(localized: "Nedbør"),
                        systemImage: "drop",
                        value: day.precipitation.map { WeatherSymbols.decimal($0, store.calendar.locale, digits: 0...1) + " mm" }
                    )
                    tile(String(localized: "Barometer"), systemImage: "barometer", value: pressureValue(day), subtitle: pressureTrend(day))
                }
            }
        case .idle, .loading:
            HStack(spacing: Spacing.s) {
                ProgressView()
                Text("Henter vejret…")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        case .failed:
            statusText(String(localized: "Kunne ikke hente vejret. Tjek forbindelsen."))
        case .unavailable:
            statusText(String(localized: "Vejret vises kun for de næste ti dage."))
        }

        Grid(alignment: .leading, horizontalSpacing: Spacing.s, verticalSpacing: Spacing.s) {
            if let sun = store.querySun {
                GridRow {
                    tile(String(localized: "Solopgang"), systemImage: "sunrise.fill", value: clockTime(sun.times.sunrise), subtitle: dayName)
                    tile(String(localized: "Solnedgang"), systemImage: "sunset.fill", value: clockTime(sun.times.sunset), subtitle: dayName)
                }
            }
            GridRow {
                tile(
                    String(localized: "Månen"),
                    systemImage: WeatherSymbols.moonSymbol(moon.name),
                    value: WeatherSymbols.moonText(moon.name),
                    subtitle: String(localized: "\(lit(moon)) oplyst")
                )
                .gridCellColumns(2)
            }
        }
    }

    private func tile(
        _ label: String,
        systemImage: String? = nil,
        arrowDirection: Double? = nil,
        value: String?,
        subtitle: String? = nil
    ) -> some View {
        WeatherTile(
            label: label,
            value: value ?? "–",
            systemImage: systemImage,
            arrowDirection: arrowDirection,
            subtitle: subtitle
        )
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func condition(_ day: MetDay) -> String? {
        WeatherSymbols.text(forSymbolCode: day.symbolCode)
    }

    private func windValue(_ day: MetDay) -> String? {
        day.maxWindSpeed.map { WeatherSymbols.decimal($0, store.calendar.locale) + " m/s" }
    }

    private func pressureValue(_ day: MetDay) -> String? {
        day.pressure.map { WeatherSymbols.decimal($0, store.calendar.locale, digits: 0...0) + " hPa" }
    }

    /// "Maks 12,3° · Min 6,1°" under the big temperature.
    private func tempRange(_ day: MetDay) -> String? {
        guard let max = day.maxTemperature, let min = day.minTemperature else { return nil }
        return String(localized: "Maks \(WeatherSymbols.decimal(max, store.calendar.locale))° · Min \(WeatherSymbols.decimal(min, store.calendar.locale))°")
    }

    /// Rising, falling or steady, over the three hours before the reference hour.
    private func pressureTrend(_ day: MetDay) -> String? {
        guard let trend = day.pressureTrend else { return nil }
        if trend > 0.3 {
            return String(localized: "↑ Stigende")
        }
        if trend < -0.3 {
            return String(localized: "↓ Faldende")
        }
        return String(localized: "→ Uændret")
    }

    private func clockTime(_ date: Date?) -> String {
        date.map(store.calendar.clockTime) ?? "–"
    }

    private var dayName: String {
        store.isQueryToday
            ? String(localized: "i dag")
            : store.calendar.short(store.calendar.monthDay(on: store.queryDate))
    }

    private var moon: MoonPhase {
        store.calendar.moonPhase(on: store.queryDate)
    }

    private func lit(_ moon: MoonPhase) -> String {
        moon.illumination
            .formatted(.percent.precision(.fractionLength(0)).locale(store.calendar.locale))
    }
}

/// One small card in the grid: gold label, big value, small note — the almanac look.
private struct WeatherTile: View {
    let label: String
    let value: String
    var systemImage: String?
    var arrowDirection: Double?
    var subtitle: String?

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            if let arrowDirection {
                WindArrow(direction: arrowDirection)
                    .font(.title3)
                    .foregroundStyle(Color.gold)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(Color.gold)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.gold)
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var spoken: String {
        var parts = [label, value]
        if let subtitle {
            parts.append(subtitle)
        }
        return parts.joined(separator: ", ")
    }
}

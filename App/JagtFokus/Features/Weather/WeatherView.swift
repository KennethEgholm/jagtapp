import SwiftUI

/// Sol og vejr for Jagtbart's chosen day and place, pushed from the sun card.
/// Weather comes from MET Norway; sun and moon are computed on the phone. Display only.
/// List sections like the species page: the day first, as on the card, then the hour
/// nearest now (midday on later days), then sun and moon.
struct WeatherView: View {
    @Environment(SeasonStore.self) private var store

    var body: some View {
        List {
            Section {
                ListHeading(title: Copy.sunWeatherTitle, eyebrow: basis)
            }
            .listSectionSpacing(.compact)

            weather

            Section {
                if let sun = store.querySun {
                    WeatherRow(title: String(localized: "Solopgang"), value: clockTime(sun.times.sunrise), iconColor: .sun) {
                        sunIcon("sunrise.fill")
                    }
                    WeatherRow(title: String(localized: "Solnedgang"), value: clockTime(sun.times.sunset), iconColor: .sun) {
                        sunIcon("sunset.fill")
                    }
                }
                WeatherRow(
                    title: String(localized: "Månen"),
                    value: WeatherSymbols.moonText(moon.name),
                    note: String(localized: "\(lit(moon)) oplyst")
                ) {
                    Image(systemName: WeatherSymbols.moonSymbol(moon.name))
                }
            } header: {
                Text("Sol og måne")
            } footer: {
                Text("Kilde: Meteorologisk institutt (MET). Vejr og måne er kun visning.")
            }
        }
        .contentMargins(.top, Spacing.xs, for: .scrollContent)
        .scrollRevealedTitle(Copy.sunWeatherTitle)
        .task(id: weatherKey) {
            if let coordinate = store.queryCoordinate?.point {
                await store.weather.load(coordinate: coordinate, on: store.queryDate, calendar: store.calendar)
            }
        }
    }

    /// Same place and date as the rows on Jagtbart, so the numbers cannot be read as "here".
    private var basis: String {
        let day = store.calendar.full(store.calendar.monthDay(on: store.queryDate))
        return Copy.basis(place: store.queryPlace.name, day: day)
    }

    /// One request per place and day: rounded coordinates and the day key.
    private var weatherKey: WeatherStore.Key? {
        store.queryCoordinate.map { WeatherStore.key(for: $0.point, on: store.queryDate, calendar: store.calendar) }
    }

    private var locale: Locale { store.calendar.locale }

    /// Two sections when MET has the day, each saying which hours it covers. Today's
    /// forecast starts at the current hour, so the day is the rest of it.
    @ViewBuilder
    private var weather: some View {
        switch store.weather.state {
        case .loaded(let day):
            Section {
                if let condition = WeatherSymbols.text(forSymbolCode: day.symbolCode) {
                    WeatherRow(title: String(localized: "Vejret"), value: condition) {
                        Image(systemName: WeatherSymbols.icon(forSymbolCode: day.symbolCode))
                    }
                }
                if let max = day.maxTemperature, let min = day.minTemperature {
                    WeatherRow(title: String(localized: "Temperatur"), value: Copy.maxMin(max, min, locale: locale)) {
                        Image(systemName: "thermometer.medium")
                    }
                }
                if let rain = day.precipitation {
                    WeatherRow(title: String(localized: "Nedbør"), value: WeatherSymbols.rain(rain, locale)) {
                        Image(systemName: "drop")
                    }
                }
                if let wind = wind(day.maxWindSpeed, from: day.maxWindDirection) {
                    WeatherRow(title: String(localized: "Kraftigste vind"), value: wind) {
                        windIcon(day.maxWindDirection)
                    }
                }
            } header: {
                Text(store.isQueryToday ? String(localized: "Resten af dagen") : String(localized: "Hele dagen"))
            }

            Section {
                if let temperature = day.temperature {
                    WeatherRow(title: String(localized: "Temperatur"), value: WeatherSymbols.decimal(temperature, locale) + "°") {
                        Image(systemName: "thermometer.medium")
                    }
                }
                if let wind = wind(day.windSpeed, from: day.windDirection) {
                    WeatherRow(title: String(localized: "Vind"), value: wind) {
                        windIcon(day.windDirection)
                    }
                }
                if let humidity = day.humidity {
                    WeatherRow(
                        title: String(localized: "Fugtighed"),
                        value: (humidity / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
                    ) {
                        Image(systemName: "humidity")
                    }
                }
                if let pressure = day.pressure {
                    WeatherRow(
                        title: String(localized: "Lufttryk"),
                        value: WeatherSymbols.pressure(pressure, locale),
                        note: pressureTrend(day)
                    ) {
                        Image(systemName: "barometer")
                    }
                }
            } header: {
                Text(store.isQueryToday ? String(localized: "Nu") : String(localized: "Midt på dagen"))
            }
        case .idle, .loading:
            Section {
                HStack(spacing: Spacing.s) {
                    ProgressView()
                    Text("Henter vejret…")
                        .foregroundStyle(.secondary)
                }
            }
        case .failed:
            Section {
                Label("Kunne ikke hente vejret. Tjek forbindelsen.", systemImage: "wifi.slash")
                    .foregroundStyle(.secondary)
            }
        case .unavailable:
            Section {
                Label("Vejret vises kun for de næste ti dage.", systemImage: "calendar")
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// "6,8 m/s fra Ø", or just the speed when MET gives no direction.
    private func wind(_ speed: Double?, from direction: Double?) -> String? {
        guard let speed else { return nil }
        let value = WeatherSymbols.decimal(speed, locale)
        guard let direction else { return value + " m/s" }
        return String(localized: "\(value) m/s fra \(WeatherSymbols.windText(fromDirection: direction))")
    }

    /// The compass arrow when MET gives a direction, else plain wind.
    @ViewBuilder
    private func windIcon(_ direction: Double?) -> some View {
        if let direction {
            WindArrow(direction: direction)
        } else {
            Image(systemName: "wind")
        }
    }

    private func sunIcon(_ systemImage: String) -> some View {
        // Multicolor draws the arrows white, invisible in light mode.
        Image(systemName: systemImage)
            .symbolRenderingMode(.hierarchical)
    }

    /// Rising, falling or steady, over the three hours after the reference hour.
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

    private var moon: MoonPhase {
        store.calendar.moonPhase(on: store.queryDate)
    }

    private func lit(_ moon: MoonPhase) -> String {
        moon.illumination
            .formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }
}

/// A weather, sun or moon fact as a list row: icon and name, value on the right, like
/// `LabeledContent` on the species page. An optional note sits under the value.
private struct WeatherRow<Icon: View>: View {
    let title: String
    let value: String
    var note: String?
    /// Sun rows are orange, like the sun card. Everything else is grey: weather is not status.
    var iconColor: Color = .secondary
    @ViewBuilder var icon: Icon

    var body: some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .monospacedDigit()
                if let note {
                    Text(note)
                        .font(.footnote)
                }
            }
        } label: {
            Label {
                Text(title)
            } icon: {
                icon
                    .foregroundStyle(iconColor)
            }
        }
    }
}

import SwiftUI

/// Sun times for Jagtbart's date and place, as their own card. Tapping opens the
/// weather and moon page for the same day and place.
struct QuerySunSection: View {
    @Environment(SeasonStore.self) private var store

    var body: some View {
        if let sun = store.querySun {
            Section {
                NavigationLink {
                    WeatherView()
                } label: {
                    SunRow(
                        calendar: store.calendar,
                        times: sun.times,
                        basis: basis,
                        weather: weatherSummary,
                        moon: store.calendar.moonPhase(on: store.queryDate)
                    )
                }
                .accessibilityHint("Åbn vejr og måne for dagen")
                .task(id: weatherTaskKey) {
                    if let coordinate = store.queryCoordinate?.point {
                        await store.weather.load(coordinate: coordinate, on: store.queryDate, calendar: store.calendar)
                    }
                }
            }
        }
    }

    /// Same place and date as the rows above, so the clock times cannot be read as “here”.
    private var basis: String {
        let day = store.calendar.full(store.calendar.monthDay(on: store.queryDate))
        return Copy.basis(place: store.queryPlace.name, day: day)
    }

    /// The day's weather for the card, or nil while loading, failed, or beyond MET's horizon.
    private var weatherSummary: MetDay? {
        if case .loaded(let day) = store.weather.state { return day }
        return nil
    }

    private var weatherTaskKey: WeatherStore.Key? {
        store.queryCoordinate.map { WeatherStore.key(for: $0.point, on: store.queryDate, calendar: store.calendar) }
    }
}

/// Sunrise and sunset for the query, with optional day weather and moon phase on
/// the card. Not tappable by itself. Display only.
struct SunRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let calendar: SeasonCalendar
    let times: SunTimes
    /// What the clock times are for. Always shown, so “here” and a chosen place cannot be confused.
    let basis: String
    /// Day weather from MET Norway. Only within MET's horizon of about ten days.
    var weather: MetDay?
    /// The moon at local noon. Computed on the phone, so always available.
    var moon: MoonPhase?

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        VStack(alignment: .leading, spacing: Spacing.xxs) {
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
                }
            }
            if let weather {
                if let max = weather.maxTemperature, let min = weather.minTemperature {
                    summaryLine(tempLine(max, min))
                }
                if weather.symbolCode != nil || weather.precipitation != nil || weather.maxWindSpeed != nil {
                    weatherLine(weather)
                }
            }
            if let moon {
                summaryLine(moonLine(moon))
            }
            // Full width, so the place and date keep to one line.
            Text(basis)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    /// One compact secondary line under the times. Wraps at accessibility sizes.
    private func summaryLine(_ text: Text) -> some View {
        text
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Temps first in the line, thermometer in front: "Maks 11,9° · Min 9,1°".
    private func tempLine(_ max: Double, _ min: Double) -> Text {
        let icon = Text(Image(systemName: "thermometer"))
        let temps = String(localized: "Maks \(WeatherSymbols.decimal(max, calendar.locale))° · Min \(WeatherSymbols.decimal(min, calendar.locale))°")
        return icon + Text("   " + temps)
    }

    /// Precipitation and wind on one line. The arrow is the compass: it points the way
    /// the wind blows, so wind from the east points west, as weather maps do.
    private func weatherLine(_ weather: MetDay) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Image(systemName: WeatherSymbols.icon(forSymbolCode: weather.symbolCode))
                .accessibilityHidden(true)
            if let rain = weather.precipitation {
                Text(verbatim: "\(WeatherSymbols.decimal(rain, calendar.locale, digits: 0...1)) mm")
            }
            if let wind = weather.maxWindSpeed {
                Text(verbatim: "·")
                if weather.windDirection != nil {
                    WindArrow(direction: weather.windDirection)
                }
                Text(verbatim: String(localized: "op til \(WeatherSymbols.decimal(wind, calendar.locale)) m/s"))
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func windArrow(_ direction: Double) -> some View {
        WindArrow(direction: direction)
    }

    private func moonLine(_ moon: MoonPhase) -> Text {
        let icon = Text(Image(systemName: WeatherSymbols.moonSymbol(moon.name)))
            .foregroundColor(.moon)
        let lit = moon.illumination
            .formatted(.percent.precision(.fractionLength(0)).locale(calendar.locale))
        return icon + Text("   " + String(localized: "\(lit) oplyst"))
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
        var parts = [String(localized: "Solopgang \(time(times.sunrise)), solnedgang \(time(times.sunset)). \(basis)")]
        if let weather {
            if let max = weather.maxTemperature, let min = weather.minTemperature {
                parts.append(String(localized: "Maks \(WeatherSymbols.decimal(max, calendar.locale))°, min \(WeatherSymbols.decimal(min, calendar.locale))°."))
            }
            if let rain = weather.precipitation {
                parts.append(String(localized: "Nedbør \(WeatherSymbols.decimal(rain, calendar.locale, digits: 0...1)) mm."))
            }
            if let wind = weather.maxWindSpeed {
                if let direction = weather.windDirection {
                    parts.append(String(localized: "Vind op til \(WeatherSymbols.decimal(wind, calendar.locale)) m/s fra \(WeatherSymbols.windText(fromDirection: direction))."))
                } else {
                    parts.append(String(localized: "Vind op til \(WeatherSymbols.decimal(wind, calendar.locale)) m/s."))
                }
            }
        }
        if let moon {
            let lit = moon.illumination
                .formatted(.percent.precision(.fractionLength(0)).locale(calendar.locale))
            parts.append(String(localized: "\(WeatherSymbols.moonText(moon.name)), \(lit) oplyst."))
        }
        return parts.joined(separator: " ")
    }
}

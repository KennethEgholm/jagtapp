import SwiftUI

/// Sun times for Jagtbart's date and place, as their own card, with the day's weather
/// and the moon. Tapping opens Sol og vejr for the same day and place.
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
                .accessibilityHint("Åbn sol og vejr for dagen")
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

/// The sun card, laid out like `QueryRow`: icon tile, small title, the times as the value.
/// Under them the day's weather and the moon as short lines, then the place and date.
/// Not tappable by itself. Display only.
struct SunRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// One column for the icons, so every line's text starts in the same place.
    @ScaledMetric(relativeTo: .body) private var iconColumn: CGFloat = 24
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
        HStack(alignment: .top, spacing: Spacing.s) {
            if !stacked {
                IconTile(systemImage: "sun.horizon.fill", color: .sun)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(Copy.sunWeatherTitle)
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
                if let weather {
                    if let sky = skyText(weather) {
                        line(sky) {
                            Image(systemName: WeatherSymbols.icon(forSymbolCode: weather.symbolCode))
                        }
                    }
                    if let wind = windText(weather) {
                        line(wind) { windIcon(weather.maxWindDirection) }
                    }
                }
                if let moon {
                    line(String(localized: "\(lit(moon)) oplyst")) {
                        Image(systemName: WeatherSymbols.moonSymbol(moon.name))
                    }
                }
                Text(basis)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    /// One secondary line with its icon in the column. Wraps rather than truncates.
    private func line<Icon: View>(_ text: String, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            icon()
                .frame(width: iconColumn)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    /// "Maks 11,9° · Min 9,1° · 0 mm", or what of it MET has.
    private func skyText(_ weather: MetDay) -> String? {
        var parts: [String] = []
        if let max = weather.maxTemperature, let min = weather.minTemperature {
            parts.append(Copy.maxMin(max, min, locale: calendar.locale))
        }
        if let rain = weather.precipitation {
            parts.append(WeatherSymbols.rain(rain, calendar.locale))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The day's strongest wind, in words as hunters say it: "Op til 6,8 m/s fra Ø".
    private func windText(_ weather: MetDay) -> String? {
        guard let wind = weather.maxWindSpeed else { return nil }
        let speed = WeatherSymbols.decimal(wind, calendar.locale)
        guard let direction = weather.maxWindDirection else {
            return String(localized: "Op til \(speed) m/s")
        }
        return String(localized: "Op til \(speed) m/s fra \(WeatherSymbols.windText(fromDirection: direction))")
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

    private func event(_ date: Date?, systemImage: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            // Multicolor draws the arrows white, invisible in light mode.
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.sun)
                .frame(width: iconColumn)
            Text(time(date))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private func time(_ date: Date?) -> String {
        date.map(calendar.clockTime) ?? "–"
    }

    private func lit(_ moon: MoonPhase) -> String {
        moon.illumination
            .formatted(.percent.precision(.fractionLength(0)).locale(calendar.locale))
    }

    private var spoken: String {
        var parts = [String(localized: "Solopgang \(time(times.sunrise)), solnedgang \(time(times.sunset)). \(basis)")]
        if let weather {
            if let condition = WeatherSymbols.text(forSymbolCode: weather.symbolCode) {
                parts.append(condition + ".")
            }
            if let max = weather.maxTemperature, let min = weather.minTemperature {
                parts.append(String(localized: "Maks \(WeatherSymbols.decimal(max, calendar.locale))°, min \(WeatherSymbols.decimal(min, calendar.locale))°."))
            }
            if let rain = weather.precipitation {
                parts.append(String(localized: "Nedbør \(WeatherSymbols.decimal(rain, calendar.locale, digits: 0...1)) mm."))
            }
            if let wind = weather.maxWindSpeed {
                if let direction = weather.maxWindDirection {
                    parts.append(String(localized: "Vind op til \(WeatherSymbols.decimal(wind, calendar.locale)) m/s fra \(WeatherSymbols.windText(fromDirection: direction))."))
                } else {
                    parts.append(String(localized: "Vind op til \(WeatherSymbols.decimal(wind, calendar.locale)) m/s."))
                }
            }
        }
        if let moon {
            parts.append(String(localized: "\(WeatherSymbols.moonText(moon.name)), \(lit(moon)) oplyst."))
        }
        return parts.joined(separator: " ")
    }
}

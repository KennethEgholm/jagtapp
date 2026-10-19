import SwiftUI

/// MET Norway's symbol codes and the moon phases, mapped to SF Symbols and words.
/// Display only, like the sun times. See the symbol table on
/// https://github.com/metno/weather-symbols.
enum WeatherSymbols {
    /// The day's icon. The `_night` codes get the moon variants.
    static func icon(forSymbolCode code: String?) -> String {
        guard let code else { return "cloud" }
        let night = code.hasSuffix("_night")
        let base = String(code.split(separator: "_").first ?? "")
        switch base {
        case "clearsky": return night ? "moon.stars" : "sun.max"
        case "fair", "partlycloudy": return night ? "cloud.moon" : "cloud.sun"
        case "cloudy": return "cloud"
        case "fog": return "cloud.fog"
        default:
            if base.contains("thunder") { return "cloud.bolt.rain" }
            if base.contains("sleet") { return "cloud.sleet" }
            if base.contains("snow") { return "cloud.snow" }
            if base.contains("rain") { return "cloud.rain" }
            return "cloud"
        }
    }

    /// The day's weather in words, or nil for a code the table does not know.
    static func text(forSymbolCode code: String?) -> String? {
        guard let code else { return nil }
        switch String(code.split(separator: "_").first ?? "") {
        case "clearsky": return String(localized: "Klart")
        case "fair": return String(localized: "Let skyet")
        case "partlycloudy": return String(localized: "Delvis skyet")
        case "cloudy": return String(localized: "Skyet")
        case "fog": return String(localized: "Tåge")
        case "rain": return String(localized: "Regn")
        case "lightrain": return String(localized: "Let regn")
        case "heavyrain": return String(localized: "Kraftig regn")
        case "rainshowers": return String(localized: "Regnbyger")
        case "lightrainshowers": return String(localized: "Let regnbyger")
        case "heavyrainshowers": return String(localized: "Kraftige regnbyger")
        case "rainandthunder": return String(localized: "Regn og torden")
        case "lightrainandthunder": return String(localized: "Let regn og torden")
        case "heavyrainandthunder": return String(localized: "Kraftig regn og torden")
        case "rainshowersandthunder": return String(localized: "Regnbyger og torden")
        case "lightrainshowersandthunder": return String(localized: "Let regnbyger og torden")
        case "heavyrainshowersandthunder": return String(localized: "Kraftige regnbyger og torden")
        case "sleet": return String(localized: "Slud")
        case "lightsleet": return String(localized: "Let slud")
        case "heavysleet": return String(localized: "Kraftig slud")
        case "sleetshowers": return String(localized: "Sludbyger")
        case "lightsleetshowers": return String(localized: "Let sludbyger")
        case "heavysleetshowers": return String(localized: "Kraftige sludbyger")
        case "sleetandthunder": return String(localized: "Slud og torden")
        case "lightsleetandthunder": return String(localized: "Let slud og torden")
        case "heavysleetandthunder": return String(localized: "Kraftig slud og torden")
        case "sleetshowersandthunder": return String(localized: "Sludbyger og torden")
        case "lightsleetshowersandthunder": return String(localized: "Let sludbyger og torden")
        case "heavysleetshowersandthunder": return String(localized: "Kraftige sludbyger og torden")
        case "snow": return String(localized: "Sne")
        case "lightsnow": return String(localized: "Let sne")
        case "heavysnow": return String(localized: "Kraftig sne")
        case "snowshowers": return String(localized: "Snebyger")
        case "lightsnowshowers": return String(localized: "Let snebyger")
        case "heavysnowshowers": return String(localized: "Kraftige snebyger")
        case "snowandthunder": return String(localized: "Sne og torden")
        case "lightsnowandthunder": return String(localized: "Let sne og torden")
        case "heavysnowandthunder": return String(localized: "Kraftig sne og torden")
        case "snowshowersandthunder": return String(localized: "Snebyger og torden")
        case "lightsnowshowersandthunder": return String(localized: "Let snebyger og torden")
        case "heavysnowshowersandthunder": return String(localized: "Kraftige snebyger og torden")
        default: return nil
        }
    }

    static func moonSymbol(_ name: MoonPhase.Name) -> String {
        switch name {
        case .new: "moonphase.new.moon"
        case .waxingCrescent: "moonphase.waxing.crescent"
        case .firstQuarter: "moonphase.first.quarter"
        case .waxingGibbous: "moonphase.waxing.gibbous"
        case .full: "moonphase.full.moon"
        case .waningGibbous: "moonphase.waning.gibbous"
        case .lastQuarter: "moonphase.last.quarter"
        case .waningCrescent: "moonphase.waning.crescent"
        }
    }

    static func moonText(_ name: MoonPhase.Name) -> String {
        switch name {
        case .new: String(localized: "Nymåne")
        case .waxingCrescent: String(localized: "Tiltagende månesegl")
        case .firstQuarter: String(localized: "Første kvarter")
        case .waxingGibbous: String(localized: "Tiltagende måne")
        case .full: String(localized: "Fuldmåne")
        case .waningGibbous: String(localized: "Aftagende måne")
        case .lastQuarter: String(localized: "Sidste kvarter")
        case .waningCrescent: String(localized: "Aftagende månesegl")
        }
    }

    /// Eight-point compass for where the wind comes from. "NØ" in Danish, "NE" in English.
    static func windText(fromDirection degrees: Double) -> String {
        let sector = Int((degrees + 22.5) / 45) % 8
        switch sector {
        case 0: return String(localized: "N")
        case 1: return String(localized: "NØ")
        case 2: return String(localized: "Ø")
        case 3: return String(localized: "SØ")
        case 4: return String(localized: "S")
        case 5: return String(localized: "SV")
        case 6: return String(localized: "V")
        default: return String(localized: "NV")
        }
    }

    /// Weather numbers in the app's language: Danish decimal comma, English point.
    static func decimal(_ value: Double, _ locale: Locale, digits: ClosedRange<Int> = 1...1) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).locale(locale))
    }
}

/// The compass arrow for the wind: points the way the wind blows, so wind from the
/// east points west, as weather maps do.
struct WindArrow: View {
    /// Where the wind comes from, in degrees from north. Nil points north.
    let direction: Double?

    var body: some View {
        Image(systemName: "arrow.up")
            .rotationEffect(.degrees(((direction ?? 0) + 180).truncatingRemainder(dividingBy: 360)))
    }
}

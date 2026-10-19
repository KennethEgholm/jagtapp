import Foundation

/// The moon's phase at one instant. Display only, like the sun times: no logic may use it.
public struct MoonPhase: Sendable, Equatable {
    public enum Name: Sendable, Equatable {
        case new
        case waxingCrescent
        case firstQuarter
        case waxingGibbous
        case full
        case waningGibbous
        case lastQuarter
        case waningCrescent
    }

    public var name: Name
    /// Share of the disc that is lit, 0 (new moon) to 1 (full moon).
    public var illumination: Double

    /// The synodic month in days: one new moon to the next.
    public static let synodicMonth = 29.530588853

    /// A known new moon: 6 January 2000 at 18:14 UTC.
    static let referenceNewMoon: Date = {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return utc.date(from: DateComponents(year: 2000, month: 1, day: 6, hour: 18, minute: 14))!
    }()

    /// A simple synodic model. Within about a day of the almanac, which is plenty for display.
    public init(at date: Date) {
        let cycles = date.timeIntervalSince(Self.referenceNewMoon) / (Self.synodicMonth * 86_400)
        var fraction = cycles.truncatingRemainder(dividingBy: 1)
        if fraction < 0 { fraction += 1 }
        illumination = (1 - cos(2 * .pi * fraction)) / 2

        // A day wide band around each of the four turning points.
        let day = 1 / Self.synodicMonth
        switch fraction {
        case ..<day, (1 - day)...1: name = .new
        case (0.25 - day)..<(0.25 + day): name = .firstQuarter
        case (0.5 - day)..<(0.5 + day): name = .full
        case (0.75 - day)..<(0.75 + day): name = .lastQuarter
        case day..<(0.25 - day): name = .waxingCrescent
        case (0.25 + day)..<(0.5 - day): name = .waxingGibbous
        case (0.5 + day)..<(0.75 - day): name = .waningGibbous
        default: name = .waningCrescent
        }
    }
}

public extension SeasonCalendar {
    /// The moon at local noon on the chosen day, in the calendar's own time zone.
    func moonPhase(on date: Date) -> MoonPhase {
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: calendar.startOfDay(for: date))
        return MoonPhase(at: noon ?? date)
    }
}

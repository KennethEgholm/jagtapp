import Foundation

/// Sunrise and sunset for one day and place. Nil when the sun does not rise or set.
/// Display only: the app never decides "jagtbar" from the clock (spec/v1.md).
public struct SunTimes: Sendable, Equatable {
    public var sunrise: Date?
    public var sunset: Date?

    public init(sunrise: Date?, sunset: Date?) {
        self.sunrise = sunrise
        self.sunset = sunset
    }
}

public extension SeasonCalendar {
    /// NOAA solar position algorithm, refined at each event. Within about a minute in Denmark.
    /// `date` picks the calendar day in Danish time; the result is in absolute time.
    func sunTimes(on date: Date, latitude: Double, longitude: Double) -> SunTimes {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = day.year, let month = day.month, let dayOfMonth = day.day else {
            return SunTimes(sunrise: nil, sunset: nil)
        }
        let midnightJD = Solar.julianDayAtMidnightUTC(year: year, month: month, day: dayOfMonth)
        let rise = Solar.eventMinutesUTC(rising: true, midnightJD: midnightJD, latitude: latitude, longitude: longitude)
        let set = Solar.eventMinutesUTC(rising: false, midnightJD: midnightJD, latitude: latitude, longitude: longitude)

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let midnight = utc.date(from: DateComponents(year: year, month: month, day: dayOfMonth))
        func at(_ minutes: Double?) -> Date? {
            guard let minutes, let midnight else { return nil }
            return midnight.addingTimeInterval(minutes * 60)
        }
        return SunTimes(sunrise: at(rise), sunset: at(set))
    }

    /// "07.42" in Danish, "07:42" in English. Rounded to the nearest minute like almanacs do.
    func clockTime(_ date: Date) -> String {
        let rounded = Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / 60).rounded() * 60)
        return rounded.formatted(dateTime.hour().minute())
    }
}

private enum Solar {
    /// Sun's centre 0.833° below the horizon: refraction plus the solar disc.
    static let zenith = 90.833

    static func julianDayAtMidnightUTC(year: Int, month: Int, day: Int) -> Double {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        let jdn = day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
        return Double(jdn) - 0.5
    }

    /// Minutes after 00:00 UTC on the given day, or nil for polar day/night.
    static func eventMinutesUTC(rising: Bool, midnightJD: Double, latitude: Double, longitude: Double) -> Double? {
        // First pass at solar noon, second pass at the event itself.
        var minutes = 720 - 4 * longitude
        for _ in 0..<2 {
            guard let next = event(rising: rising, jd: midnightJD + minutes / 1440, latitude: latitude, longitude: longitude) else {
                return nil
            }
            minutes = next
        }
        return minutes
    }

    private static func event(rising: Bool, jd: Double, latitude: Double, longitude: Double) -> Double? {
        let t = (jd - 2451545) / 36525
        let (declination, equationOfTime) = position(t)
        let lat = radians(latitude)
        let cosHA = cos(radians(zenith)) / (cos(lat) * cos(declination)) - tan(lat) * tan(declination)
        guard (-1...1).contains(cosHA) else { return nil }
        let hourAngle = degrees(acos(cosHA))
        let noon = 720 - 4 * longitude - equationOfTime
        return rising ? noon - 4 * hourAngle : noon + 4 * hourAngle
    }

    /// Declination (radians) and equation of time (minutes) at Julian century `t`.
    private static func position(_ t: Double) -> (Double, Double) {
        let l0 = radians((280.46646 + t * (36000.76983 + t * 0.0003032)).truncatingRemainder(dividingBy: 360))
        let m = radians(357.52911 + t * (35999.05029 - 0.0001537 * t))
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let center = sin(m) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * m) * (0.019993 - 0.000101 * t)
            + sin(3 * m) * 0.000289
        let omega = radians(125.04 - 1934.136 * t)
        let lambda = radians(degrees(l0) + center - 0.00569 - 0.00478 * sin(omega))
        let meanObliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let obliquity = radians(meanObliquity + 0.00256 * cos(omega))
        let declination = asin(sin(obliquity) * sin(lambda))
        let y = pow(tan(obliquity / 2), 2)
        let equationOfTime = 4 * degrees(
            y * sin(2 * l0) - 2 * e * sin(m) + 4 * e * y * sin(m) * cos(2 * l0)
                - 0.5 * y * y * sin(4 * l0) - 1.25 * e * e * sin(2 * m)
        )
        return (declination, equationOfTime)
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}

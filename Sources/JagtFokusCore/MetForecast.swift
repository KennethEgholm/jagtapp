import Foundation

/// Weather for one day, as the weather page shows it. Display only, like the sun times.
public struct MetDay: Sendable, Equatable {
    /// A MET Norway symbol code, for example "partlycloudy_day".
    public var symbolCode: String?
    public var minTemperature: Double?
    public var maxTemperature: Double?
    /// The strongest wind of the day, in m/s.
    public var maxWindSpeed: Double?
    /// Where that wind comes from, in degrees from north.
    public var windDirection: Double?
    /// Millimetres through the day, counted in six-hour blocks.
    public var precipitation: Double?
    /// Humidity at the reference hour, in percent.
    public var humidity: Double?
    /// Temperature at the reference hour — the "now" temperature.
    public var temperature: Double?
    /// Sea-level pressure at the reference hour, hPa.
    public var pressure: Double?
    /// How the pressure is expected to move over the three hours after the
    /// reference hour, hPa. MET's forecast only has the hours ahead, so the trend
    /// looks forward, on later days as well as today.
    public var pressureTrend: Double?
}

/// MET Norway Locationforecast 2.0 (compact), decoded. The network call itself lives
/// in the app; Core holds the model, the decoder and the day summary so they can be tested.
public struct MetForecast: Sendable, Equatable {
    public var updatedAt: Date?
    public var timeseries: [Hour]

    public struct Hour: Sendable, Equatable {
        public var time: Date
        public var temperature: Double?
        public var humidity: Double?
        /// Sea-level pressure, hPa.
        public var pressure: Double?
        public var windSpeed: Double?
        public var windDirection: Double?
        /// Symbol for the six hours that follow `time`.
        public var symbolCode: String?
        /// Millimetres over the six hours that follow `time`.
        public var precipitation: Double?
    }
}

public extension MetForecast {
    /// Tolerant: a missing field stays nil, an unknown one is ignored.
    static func decode(from data: Data) throws -> MetForecast {
        let response = try decoder.decode(Response.self, from: data)
        let hours = (response.properties.timeseries ?? []).map { entry -> Hour in
            let details = entry.payload?.instant?.details
            return Hour(
                time: entry.time,
                temperature: details?.airTemperature,
                humidity: details?.relativeHumidity,
                pressure: details?.airPressureAtSeaLevel,
                windSpeed: details?.windSpeed,
                windDirection: details?.windFromDirection,
                symbolCode: entry.payload?.next6Hours?.summary?.symbolCode,
                precipitation: entry.payload?.next6Hours?.details?.precipitationAmount
            )
        }
        return MetForecast(updatedAt: response.properties.meta?.updatedAt, timeseries: hours)
    }

    /// MET asks for two decimals: enough for a place, coarse enough for privacy.
    static func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    static func requestURL(latitude: Double, longitude: Double) -> URL {
        var components = URLComponents(string: "https://api.met.no/weatherapi/locationforecast/2.0/compact")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(rounded(latitude))),
            URLQueryItem(name: "lon", value: String(rounded(longitude))),
        ]
        return components.url!
    }

    /// The chosen day's weather, grouped by the clock in `timeZone` — Danish, whatever the
    /// phone is set to. Nil when the day has no forecast: in the past, or beyond MET's
    /// horizon of about ten days. `now` picks the reference hour for humidity and
    /// pressure: the hour nearest the moment, or midday on later days.
    func day(on date: Date, timeZone: TimeZone, now: Date? = nil) -> MetDay? {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = timeZone
        let dayComponents = local.dateComponents([.year, .month, .day], from: date)
        let hours = timeseries.filter { local.dateComponents([.year, .month, .day], from: $0.time) == dayComponents }
        guard !hours.isEmpty else { return nil }

        var day = MetDay(
            symbolCode: nil, minTemperature: nil, maxTemperature: nil, maxWindSpeed: nil,
            windDirection: nil, precipitation: nil, humidity: nil, temperature: nil,
            pressure: nil, pressureTrend: nil
        )
        for hour in hours {
            if let temperature = hour.temperature {
                day.minTemperature = min(day.minTemperature ?? temperature, temperature)
                day.maxTemperature = max(day.maxTemperature ?? temperature, temperature)
            }
            if let wind = hour.windSpeed, wind > (day.maxWindSpeed ?? -1) {
                // The direction of the strongest wind is the one that matters.
                day.maxWindSpeed = wind
                day.windDirection = hour.windDirection
            }
        }

        // The hour the humidity and pressure readings belong to: nearest the moment
        // when the chosen day is today, otherwise midday.
        if let reference = referenceHour(hours: hours, on: date, local: local, now: now) {
            day.humidity = reference.humidity
            day.temperature = reference.temperature
            day.pressure = reference.pressure
            // The pressure's move over the next three hours.
            if let ahead = timeseries.first(where: {
                $0.time == reference.time.addingTimeInterval(3 * 3600)
            }), let referencePressure = reference.pressure, let aheadPressure = ahead.pressure {
                day.pressureTrend = aheadPressure - referencePressure
            }
        }

        // Precipitation and the day's symbol come from the six-hour blocks that start at
        // 00, 06, 12 and 18 local time. Every other hour would double count.
        let blocks = [0, 6, 12, 18].compactMap { hour in
            hours.first { local.component(.hour, from: $0.time) == hour }
        }
        let rains = blocks.compactMap(\.precipitation)
        if !rains.isEmpty {
            day.precipitation = rains.reduce(0, +)
        }
        day.symbolCode = symbol(blocks: blocks, local: local)
        return day
    }

    /// The reference hour: nearest `now` when it falls inside the day, else 12 local.
    private func referenceHour(hours: [Hour], on date: Date, local: Calendar, now: Date?) -> Hour? {
        let isToday = now.map { local.isDate($0, inSameDayAs: date) } ?? false
        let moment: Date
        if isToday, let now {
            moment = now
        } else {
            guard let midday = local.date(bySettingHour: 12, minute: 0, second: 0, of: date) else { return nil }
            moment = midday
        }
        return hours.min(by: { abs($0.time.timeIntervalSince(moment)) < abs($1.time.timeIntervalSince(moment)) })
    }

    /// A block with rain says more than a dry one; otherwise the block over midday.
    private func symbol(blocks: [Hour], local: Calendar) -> String? {
        if let wettest = blocks.max(by: { ($0.precipitation ?? 0) < ($1.precipitation ?? 0) }),
           let code = wettest.symbolCode, (wettest.precipitation ?? 0) > 0.05 {
            return code
        }
        let midday = blocks.first { local.component(.hour, from: $0.time) == 12 }
        return (midday ?? blocks.first)?.symbolCode
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private struct Response: Decodable {
    var properties: Properties

    struct Properties: Decodable {
        var meta: Meta?
        var timeseries: [Entry]?

        enum CodingKeys: String, CodingKey {
            case meta
            case timeseries
        }
    }

    struct Meta: Decodable {
        var updatedAt: Date?

        enum CodingKeys: String, CodingKey {
            case updatedAt = "updated_at"
        }
    }

    struct Entry: Decodable {
        var time: Date
        var payload: Payload?

        enum CodingKeys: String, CodingKey {
            case time
            case payload = "data"
        }

        struct Payload: Decodable {
            var instant: Instant?
            var next6Hours: Block?

            enum CodingKeys: String, CodingKey {
                case instant
                case next6Hours = "next_6_hours"
            }
        }

        struct Instant: Decodable {
            var details: Details?
        }

        struct Block: Decodable {
            var summary: Summary?
            var details: Precip?
        }

        struct Summary: Decodable {
            var symbolCode: String?

            enum CodingKeys: String, CodingKey {
                case symbolCode = "symbol_code"
            }
        }

        struct Precip: Decodable {
            var precipitationAmount: Double?

            enum CodingKeys: String, CodingKey {
                case precipitationAmount = "precipitation_amount"
            }
        }

        struct Details: Decodable {
            var airTemperature: Double?
            var relativeHumidity: Double?
            var airPressureAtSeaLevel: Double?
            var windSpeed: Double?
            var windFromDirection: Double?

            enum CodingKeys: String, CodingKey {
                case airTemperature = "air_temperature"
                case relativeHumidity = "relative_humidity"
                case airPressureAtSeaLevel = "air_pressure_at_sea_level"
                case windSpeed = "wind_speed"
                case windFromDirection = "wind_from_direction"
            }
        }
    }
}

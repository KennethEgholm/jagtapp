import Foundation
import Testing
@testable import JagtFokusCore

/// A trimmed response from api.met.no (Locationforecast 2.0 compact), recorded 19 October 2026.
/// 19 October 2026 is CEST, UTC+2, so local midnight sits at 22:00Z the day before.
struct MetForecastTests {
    let met = TimeZone(identifier: "Europe/Copenhagen")!

    func danish(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = met
        return utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func decode(_ json: String) throws -> MetForecast {
        try MetForecast.decode(from: Data(json.utf8))
    }

    static let fixture = """
    {"properties":{"meta":{"updated_at":"2026-10-19T09:31:55Z"},"timeseries":[
      {"time":"2026-10-19T07:00:00Z","data":{"instant":{"details":{"air_temperature":6.0,"relative_humidity":70.0,"air_pressure_at_sea_level":1036.7,"wind_speed":3.0,"wind_from_direction":80.0}},"next_6_hours":{"summary":{"symbol_code":"fair_day"},"details":{"precipitation_amount":0.0}}}},
      {"time":"2026-10-19T10:00:00Z","data":{"instant":{"details":{"air_temperature":10.1,"relative_humidity":68.6,"air_pressure_at_sea_level":1036.3,"wind_speed":5.1}},"next_6_hours":{"summary":{"symbol_code":"partlycloudy_day"},"details":{"precipitation_amount":0.0}}}},
      {"time":"2026-10-19T12:00:00Z","data":{"instant":{"details":{"air_temperature":12.3,"relative_humidity":65.0,"air_pressure_at_sea_level":1035.9,"wind_speed":4.0}}}},
      {"time":"2026-10-19T15:00:00Z","data":{"instant":{"details":{"air_temperature":11.0,"relative_humidity":67.0,"air_pressure_at_sea_level":1035.0,"wind_speed":6.2,"wind_from_direction":225.0}},"next_6_hours":{"summary":{"symbol_code":"heavyrain_day"},"details":{"precipitation_amount":5.0}}}},
      {"time":"2026-10-19T16:00:00Z","data":{"instant":{"details":{"air_temperature":10.4,"relative_humidity":69.0,"air_pressure_at_sea_level":1034.8,"wind_speed":5.8}},"next_6_hours":{"summary":{"symbol_code":"rain_day"},"details":{"precipitation_amount":1.2}}}},
      {"time":"2026-10-20T07:00:00Z","data":{"instant":{"details":{"air_temperature":8.0,"relative_humidity":75.0,"air_pressure_at_sea_level":1037.0,"wind_speed":2.0}},"next_6_hours":{"summary":{"symbol_code":"partlycloudy_day"},"details":{"precipitation_amount":0.0}}}},
      {"time":"2026-10-20T10:00:00Z","data":{"instant":{"details":{"air_temperature":11.0,"relative_humidity":64.0,"air_pressure_at_sea_level":1036.0}}}}
    ]}}
    """

    /// Danish local time. October 2026 is CEST, UTC+2.
    func local(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10) -> Date {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = met
        return utc.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func decodesTheRecordedFields() throws {
        let forecast = try decode(Self.fixture)
        #expect(forecast.updatedAt == ISO8601DateFormatter().date(from: "2026-10-19T09:31:55Z"))
        #expect(forecast.timeseries.count == 7)
        let first = forecast.timeseries[0]
        #expect(first.time == ISO8601DateFormatter().date(from: "2026-10-19T07:00:00Z"))
        #expect(first.temperature == 6.0)
        #expect(first.humidity == 70.0)
        #expect(first.pressure == 1036.7)
        #expect(first.windSpeed == 3.0)
        #expect(first.windDirection == 80.0)
        #expect(first.symbolCode == "fair_day")
        #expect(first.precipitation == 0.0)
    }

    @Test func missingFieldsStayNil() throws {
        let forecast = try decode("""
        {"properties":{"timeseries":[{"time":"2026-10-19T12:00:00Z"}]}}
        """)
        #expect(forecast.timeseries.count == 1)
        #expect(forecast.updatedAt == nil)
        #expect(forecast.timeseries[0].temperature == nil)
        #expect(forecast.timeseries[0].symbolCode == nil)
        #expect(forecast.timeseries[0].precipitation == nil)
    }

    @Test func dayGroupsByTheLocalClock() throws {
        let forecast = try decode(Self.fixture)
        let day = try #require(forecast.day(on: danish(2026, 10, 19), timeZone: met))
        #expect(day.minTemperature == 6.0)
        #expect(day.maxTemperature == 12.3)
        #expect(day.maxWindSpeed == 6.2)
        // The direction belongs to the strongest wind, not to the first hour.
        #expect(day.maxWindDirection == 225.0)
    }

    /// The six-hour blocks follow on from each other: 09–15, then the next step after
    /// 15, 17–23. The 18:00 block overlaps 17–23 and stays out, or its rain would count twice.
    @Test func sixHourBlocksFollowOnWithoutOverlap() throws {
        let forecast = try decode(Self.fixture)
        let day = try #require(forecast.day(on: danish(2026, 10, 19), timeZone: met))
        #expect(day.precipitation == 5.0)
    }

    /// The 17:00 block has 5 mm, so its rain symbol beats the dry ones.
    @Test func aWetBlockWinsTheSymbol() throws {
        let forecast = try decode(Self.fixture)
        let day = try #require(forecast.day(on: danish(2026, 10, 19), timeZone: met))
        #expect(day.symbolCode == "heavyrain_day")
    }

    /// One timeseries entry. `hour` and `sixHours` are MET's next_1_hours and
    /// next_6_hours: a symbol and millimetres.
    func entry(_ time: String, hour: (String, Double)? = nil, sixHours: (String, Double)? = nil) -> String {
        var data = #""instant":{"details":{"air_temperature":10.0}}"#
        if let (symbol, mm) = hour {
            data += #","next_1_hours":{"summary":{"symbol_code":"\#(symbol)"},"details":{"precipitation_amount":\#(mm)}}"#
        }
        if let (symbol, mm) = sixHours {
            data += #","next_6_hours":{"summary":{"symbol_code":"\#(symbol)"},"details":{"precipitation_amount":\#(mm)}}"#
        }
        return #"{"time":"\#(time)","data":{\#(data)}}"#
    }

    func forecast(_ entries: [String]) throws -> MetForecast {
        try decode(#"{"properties":{"timeseries":["# + entries.joined(separator: ",") + "]}}")
    }

    /// From about the third day MET only has steps at 00, 06, 12 and 18 UTC: 02, 08, 14
    /// and 20 Danish summer time. Every step counts, and the wettest gives the symbol.
    @Test func laterDaysUseTheSixHourSteps() throws {
        let forecast = try forecast([
            entry("2026-10-23T00:00:00Z", sixHours: ("cloudy", 0.4)),
            entry("2026-10-23T06:00:00Z", sixHours: ("partlycloudy_day", 0.0)),
            entry("2026-10-23T12:00:00Z", sixHours: ("lightrain_day", 1.1)),
            entry("2026-10-23T18:00:00Z", sixHours: ("cloudy_night", 0.0)),
        ])
        let day = try #require(forecast.day(on: danish(2026, 10, 23), timeZone: met))
        #expect(abs((day.precipitation ?? 0) - 1.5) < 0.001)
        #expect(day.symbolCode == "lightrain_day")
    }

    /// A dry later day takes the symbol of the step over midday: 08–14 local.
    @Test func aDryLaterDayTakesTheStepOverMidday() throws {
        let forecast = try forecast([
            entry("2026-10-23T00:00:00Z", sixHours: ("cloudy_night", 0.0)),
            entry("2026-10-23T06:00:00Z", sixHours: ("fair_day", 0.0)),
            entry("2026-10-23T12:00:00Z", sixHours: ("cloudy", 0.0)),
            entry("2026-10-23T18:00:00Z", sixHours: ("clearsky_night", 0.0)),
        ])
        let day = try #require(forecast.day(on: danish(2026, 10, 23), timeZone: met))
        #expect(day.symbolCode == "fair_day")
    }

    /// In MET's hourly part each hour counts once, from next_1_hours. The six-hour
    /// amounts there overlap and would count the same rain up to six times.
    @Test func hourlyStepsCountEachHourOnce() throws {
        let forecast = try forecast((12...21).map { hour in
            entry("2026-10-19T\(hour):00:00Z", hour: ("cloudy", 0.1), sixHours: ("rain", 9.9))
        })
        let day = try #require(forecast.day(on: danish(2026, 10, 19), timeZone: met))
        #expect(abs((day.precipitation ?? 0) - 1.0) < 0.001)
    }

    /// Opened at 13:31 the forecast starts at 14:00, past midday. The day's symbol is
    /// the afternoon's, not the evening block's night symbol.
    @Test func afterMiddayTheSymbolIsTheHoursLeft() throws {
        let forecast = try forecast((12...21).map { hour in
            entry(
                "2026-10-19T\(hour):00:00Z",
                hour: ("partlycloudy_day", 0.0),
                sixHours: (hour < 16 ? "partlycloudy_day" : "partlycloudy_night", 0.0)
            )
        })
        let day = try #require(forecast.day(on: danish(2026, 10, 19), timeZone: met, now: local(19, 13, 31)))
        #expect(day.symbolCode == "partlycloudy_day")
    }

    /// All blocks dry: the block over midday gives the day's symbol.
    @Test func aDryDayTakesTheMiddaySymbol() throws {
        let forecast = try decode("""
        {"properties":{"timeseries":[
          {"time":"2026-10-19T10:00:00Z","data":{"instant":{"details":{"air_temperature":10.1}},"next_6_hours":{"summary":{"symbol_code":"partlycloudy_day"},"details":{"precipitation_amount":0.0}}}},
          {"time":"2026-10-19T16:00:00Z","data":{"instant":{"details":{"air_temperature":10.4}},"next_6_hours":{"summary":{"symbol_code":"fair_day"},"details":{"precipitation_amount":0.0}}}}
        ]}}
        """)
        let day = try #require(forecast.day(on: danish(2026, 10, 19), timeZone: met))
        #expect(day.symbolCode == "partlycloudy_day")
        #expect(day.precipitation == 0.0)
    }

    /// The next day's hours do not leak into this one.
    @Test func theNeighbouringDayStaysOut() throws {
        let forecast = try decode(Self.fixture)
        #expect(forecast.day(on: danish(2026, 10, 20), timeZone: met)!.maxTemperature == 11.0)
        #expect(forecast.day(on: danish(2026, 10, 18), timeZone: met) == nil)
        #expect(forecast.day(on: danish(2026, 11, 19), timeZone: met) == nil)
    }

    /// The trend looks forward: the pressure three hours after the reference hour.
    @Test func referenceHourIsNearestNow() throws {
        let forecast = try decode(Self.fixture)
        // 13:10 local is nearest the 14:00 reading, and 17:00 has the pressure three ahead.
        let day = try #require(forecast.day(on: danish(2026, 10, 19), timeZone: met, now: local(19, 13, 10)))
        #expect(day.temperature == 12.3)
        #expect(day.humidity == 65.0)
        #expect(day.pressure == 1035.9)
        #expect(abs((day.pressureTrend ?? 0) + 0.9) < 0.001)
    }

    /// The wind on the weather page is the reference hour's, like the temperature.
    /// The day's strongest stays for the sun card.
    @Test func referenceHourHasItsOwnWind() throws {
        let forecast = try decode(Self.fixture)
        let day = try #require(forecast.day(on: danish(2026, 10, 19), timeZone: met, now: local(19, 9, 10)))
        #expect(day.windSpeed == 3.0)
        #expect(day.windDirection == 80.0)
        #expect(day.maxWindSpeed == 6.2)
        #expect(day.maxWindDirection == 225.0)
    }

    /// On later days the readings come from midday. When the hour three ahead is
    /// beyond the forecast, there is no trend.
    @Test func referenceHourIsMiddayOnLaterDays() throws {
        let forecast = try decode(Self.fixture)
        let day = try #require(forecast.day(on: danish(2026, 10, 20), timeZone: met, now: local(19, 17, 10)))
        #expect(day.temperature == 11.0)
        #expect(day.humidity == 64.0)
        #expect(day.pressure == 1036.0)
        #expect(day.pressureTrend == nil)
    }

    @Test func twoDecimalsInTheRequest() {
        let url = MetForecast.requestURL(latitude: 56.1629, longitude: 10.2039)
        #expect(url.absoluteString == "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=56.16&lon=10.2")
    }

    @Test func roundingKeepsTwoDecimals() {
        #expect(MetForecast.rounded(56.1629) == 56.16)
        #expect(MetForecast.rounded(10.2039) == 10.2)
    }
}

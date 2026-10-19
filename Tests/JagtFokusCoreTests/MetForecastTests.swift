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
        #expect(day.windDirection == 225.0)
    }

    /// 5.0 mm sits on 17:00 local, inside the 12–18 block. Only the blocks at 00, 06,
    /// 12 and 18 count, or the same rain would be summed twice.
    @Test func precipitationOnlyCountsTheSixHourBlocks() throws {
        let forecast = try decode(Self.fixture)
        let day = try #require(forecast.day(on: danish(2026, 10, 19), timeZone: met))
        #expect(day.precipitation == 1.2)
    }

    /// The 18:00 block has 1.2 mm, so its rain symbol beats the dry ones.
    @Test func aWetBlockWinsTheSymbol() throws {
        let forecast = try decode(Self.fixture)
        let day = try #require(forecast.day(on: danish(2026, 10, 19), timeZone: met))
        #expect(day.symbolCode == "rain_day")
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

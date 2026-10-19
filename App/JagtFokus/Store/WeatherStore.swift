import Foundation
import Observation

/// Weather for Jagtbart's chosen day and place, from MET Norway Locationforecast 2.0.
/// Display only, on the sun card and on the weather page. One request per place and
/// day at most, and answers younger than ten minutes are reused, as MET asks.
@MainActor
@Observable
final class WeatherStore {
    enum State: Equatable {
        case idle
        case loading
        /// No forecast for the day: it is in the past or beyond MET's horizon.
        case unavailable
        case failed
        case loaded(MetDay)
    }

    private(set) var state: State = .idle

    struct Key: Hashable {
        var latitude: Double
        var longitude: Double
        var day: String
    }

    private struct Cached {
        var data: Data
        var fetched: Date
    }

    private var cache: [Key: Cached] = [:]
    /// MET asks for data to be reused within ten minutes.
    private let maxAge: TimeInterval = 600

    /// The cache key for Jagtbart's query: rounded coordinates and the chosen day.
    static func key(for coordinate: Coordinate, on date: Date, calendar: SeasonCalendar) -> Key {
        Key(
            latitude: MetForecast.rounded(coordinate.latitude),
            longitude: MetForecast.rounded(coordinate.longitude),
            day: calendar.dayKey(for: date)
        )
    }

    func load(coordinate: Coordinate, on date: Date, calendar: SeasonCalendar) async {
        let key = Self.key(for: coordinate, on: date, calendar: calendar)
        let timeZone = calendar.calendar.timeZone
        if let cached = cache[key], Date().timeIntervalSince(cached.fetched) < maxAge {
            apply(cached.data, on: date, timeZone: timeZone)
            return
        }
        state = .loading
        var request = URLRequest(url: MetForecast.requestURL(latitude: key.latitude, longitude: key.longitude))
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            apply(data, on: date, timeZone: timeZone)
            cache[key] = Cached(data: data, fetched: Date())
        } catch {
            // A cancelled load belongs to a view that has already moved on.
            guard !Task.isCancelled else { return }
            if let cached = cache[key] {
                apply(cached.data, on: date, timeZone: timeZone)
            } else {
                state = .failed
            }
        }
    }

    private func apply(_ data: Data, on date: Date, timeZone: TimeZone) {
        guard let forecast = try? MetForecast.decode(from: data) else {
            state = .failed
            return
        }
        guard let day = forecast.day(on: date, timeZone: timeZone, now: Date()) else {
            state = .unavailable
            return
        }
        state = .loaded(day)
    }

    /// MET rejects requests without a User-Agent that says who is asking.
    static var userAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "JagtFokus/\(version) +https://github.com/KennethEgholm/jagtapp"
    }
}

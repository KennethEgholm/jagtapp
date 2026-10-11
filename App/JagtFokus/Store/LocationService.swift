import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    /// Position plus the geocoder's place names for it.
    var onFix: ((Coordinate, [String]) -> Void)?
    var onDenied: (() -> Void)?
    var onUnavailable: (() -> Void)?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    /// From `locationManagerDidChangeAuthorization`, which fires on setup and on every change.
    /// Reading `authorizationStatus` or `locationServicesEnabled()` elsewhere blocks the main thread.
    private var status: CLAuthorizationStatus?
    private var wantsLocation = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request() {
        wantsLocation = true
        // Before the first callback: it arrives shortly and acts then.
        guard let status else { return }
        act(on: status)
    }

    /// Location services switched off globally also reports `.denied`.
    private func act(on status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            onDenied?()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.status = status
            if wantsLocation {
                act(on: status)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            await reverse(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            onUnavailable?()
        }
    }

    private func reverse(_ location: CLLocation) async {
        // One geocode at a time; overlapping requests fail and could overwrite a good fix.
        guard !geocoder.isGeocoding else { return }
        do {
            let marks = try await geocoder.reverseGeocodeLocation(location)
            let names = marks.flatMap { mark -> [String] in
                [
                    mark.name,
                    mark.locality,
                    mark.subLocality,
                    mark.subAdministrativeArea,
                    mark.administrativeArea,
                    mark.inlandWater,
                    mark.ocean
                ].compactMap { $0 } + (mark.areasOfInterest ?? [])
            }
            let point = Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            onFix?(point, names)
        } catch {
            onUnavailable?()
        }
    }
}

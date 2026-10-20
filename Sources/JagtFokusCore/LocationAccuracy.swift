import Foundation

/// When the map says that precise location is off. Core has no CoreLocation, so the app
/// maps the system's status to `Access`.
public enum LocationAccuracy {
    public enum Access: Equatable, Sendable {
        case notDetermined, restricted, denied, whenInUse, always
    }

    /// Only with permission: the puck is then a 1–3 km circle and a boundary map misleads.
    /// Without permission the system may read "reduced" too, and the notice would be noise.
    public static func showsReducedNotice(access: Access, isReduced: Bool) -> Bool {
        guard isReduced else { return false }
        switch access {
        case .whenInUse, .always: return true
        case .notDetermined, .restricted, .denied: return false
        }
    }
}

import SwiftUI

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

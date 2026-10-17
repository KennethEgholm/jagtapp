import SwiftUI

/// Design tokens. See `spec/design.md`.
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
}

enum Radius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xlarge: CGFloat = 22
}

extension ShapeStyle where Self == Color {
    /// Jagtbar. Same as the app tint.
    static var seasonOpen: Color { .accentColor }
    /// Open, last day within a week.
    static var seasonClosingSoon: Color { Color(.amber) }
    /// Local override applies.
    static var localTime: Color { Color(.brass) }
    /// Fixed brand green for filled tiles. Light accent is too pale behind white symbols in dark mode.
    static var forest: Color { Color(red: 0.184, green: 0.420, blue: 0.278) }
    /// Sunrise and sunset. Display only, not status.
    static var sun: Color { .orange }
    /// Lighter green glow in the welcome background.
    static var brandGlow: Color { Color(red: 0.13, green: 0.30, blue: 0.20) }
}

/// Settings-style leading icon: white symbol on a tinted rounded square.
struct IconTile: View {
    let systemImage: String
    var color: Color = .forest

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 30

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// The app mark, clipped like a home screen icon.
struct BrandMark: View {
    var size: CGFloat = 88

    var body: some View {
        Image(.brandMark)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
            .accessibilityLabel("JagtFokus")
    }
}

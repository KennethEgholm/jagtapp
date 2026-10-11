import SwiftUI

extension View {
    /// Inline nav title that fades in once the in-content heading has scrolled away.
    /// Pair with a wrapping heading as the first list row, so long names never truncate.
    func scrollRevealedTitle(_ title: String) -> some View {
        modifier(ScrollRevealedTitle(title: title))
    }
}

private struct ScrollRevealedTitle: ViewModifier {
    let title: String
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top > 44
            } action: { _, past in
                visible = past
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                        .opacity(visible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.15), value: visible)
                        .accessibilityHidden(!visible)
                }
            }
    }
}

/// Big wrapping heading as a list row with no card behind it.
/// Inset from the row's rounded corners: List clips row content to them, cutting the first glyph.
struct ListHeading: View {
    let title: String
    var eyebrow: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if let eyebrow {
                Text(eyebrow)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.title.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.xs, bottom: 0, trailing: Spacing.xs))
    }
}

import SwiftUI
import UIKit

/// Photo card with the credit line the license requires.
/// Renders nothing if the asset is missing, e.g. a species added by newer remote data.
struct SpeciesPhotoView: View {
    let photo: IdentifiedPhoto
    let speciesName: String

    var body: some View {
        if let image = UIImage(named: photo.assetName) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(3 / 2, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xlarge, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.xlarge, style: .continuous)
                            .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                    }
                    .accessibilityLabel("Foto af \(speciesName)")

                // Clear of the row's rounded bottom corner, which clips.
                credit
                    .padding(.horizontal, Spacing.xs)
                    .padding(.bottom, Spacing.xxs)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    @ViewBuilder
    private var credit: some View {
        let text = Text("Foto: \(photo.photo.artist) · \(photo.photo.license) · Wikimedia Commons")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        if let url = URL(string: photo.photo.sourceURL) {
            Link(destination: url) { text }
                .tint(.secondary)
                .accessibilityLabel("Fotokredit: \(photo.photo.artist), \(photo.photo.license)")
                .accessibilityHint("Åbner billedet på Wikimedia Commons")
        } else {
            text
        }
    }
}

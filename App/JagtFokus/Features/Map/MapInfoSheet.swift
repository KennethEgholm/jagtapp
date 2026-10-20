import SwiftUI

/// Om kortet: what the boundaries are, and who the map data is from.
struct MapInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(Copy.parcelDisclaimer)
                }
                Section(Copy.mapParcels) {
                    Text(verbatim: CadastreService.attribution)
                    Link(destination: CadastreService.licenceURL) {
                        Label("Licens", systemImage: "arrow.up.right.square")
                    }
                }
                Section(Copy.mapBasemap) {
                    Text(verbatim: OpenFreeMap.attribution)
                }
            }
            .navigationTitle(Copy.mapInfoTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Luk") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

import SwiftUI

/// Kort: the basemap full-bleed down to the tab bar, below a system navigation bar. Boundaries, the status
/// card and saved areas come in later slices.
struct MapTab: View {
    @Environment(SeasonStore.self) private var store

    var body: some View {
        NavigationStack {
            ParcelMapView(
                camera: startCamera,
                parcels: nil,
                saveFrame: nil,
                onRegionChange: { _, _ in }
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(Copy.mapTab)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    /// Flies the map when the GPS fix or the chosen place changes. The GPS position, else the chosen place, else all of Denmark. DEBUG `-map lat,lon,zoom` wins.
    private var startCamera: MapCamera {
        #if DEBUG
        let parts = (UserDefaults.standard.string(forKey: "map") ?? "").split(separator: ",").compactMap { Double($0) }
        if parts.count == 3 {
            return MapCamera(center: Coordinate(latitude: parts[0], longitude: parts[1]), zoom: parts[2])
        }
        #endif
        return MapCamera.start(at: store.queryCoordinate?.point, isExact: store.queryCoordinate?.isExact ?? false)
    }
}

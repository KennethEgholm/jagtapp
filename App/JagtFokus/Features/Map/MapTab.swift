import SwiftUI

/// Kort: the basemap full-bleed down to the tab bar, below a system navigation bar.
/// Boundaries, the status card and saved areas come in later slices.
///
/// The camera moves only on explicit events: the start, the first exact GPS fix when
/// the user has not touched the map, and `fly(to:)`. Later GPS fixes and a new place on
/// Jagtbart never move it.
struct MapTab: View {
    @Environment(SeasonStore.self) private var store
    @State private var request: MapCameraRequest?
    /// The camera is settled: the user moved it, the start was already exact, or the GPS fix has been used.
    @State private var settled = false

    var body: some View {
        NavigationStack {
            ParcelMapView(
                initialCamera: startCamera,
                request: request,
                onUserMove: { settled = true },
                parcels: nil,
                saveFrame: nil,
                onRegionChange: { _, _ in }
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(Copy.mapTab)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            // The map has just started at the best camera there is. An exact fix or `-map` needs no flight.
            if exactFix != nil || debugCamera != nil { settled = true }
        }
        .onChange(of: exactFix) { _, fix in
            guard let fix, !settled else { return }
            settled = true
            fly(to: MapCamera.start(at: fix, isExact: true))
        }
    }

    /// For the buttons that come later (centre on me, a saved area).
    private func fly(to camera: MapCamera) {
        request = MapCameraRequest(id: (request?.id ?? 0) + 1, camera: camera)
    }

    private var exactFix: Coordinate? {
        guard let query = store.queryCoordinate, query.isExact else { return nil }
        return query.point
    }

    /// DEBUG `-map lat,lon,zoom`.
    private var debugCamera: MapCamera? {
        #if DEBUG
        let parts = (UserDefaults.standard.string(forKey: "map") ?? "").split(separator: ",").compactMap { Double($0) }
        if parts.count == 3 {
            return MapCamera(center: Coordinate(latitude: parts[0], longitude: parts[1]), zoom: parts[2])
        }
        #endif
        return nil
    }

    /// Where the map starts: `-map`, else the GPS position, else the chosen place, else all of Denmark.
    /// The map reads it once, when it is made.
    private var startCamera: MapCamera {
        debugCamera ?? MapCamera.start(at: store.queryCoordinate?.point, isExact: store.queryCoordinate?.isExact ?? false)
    }
}

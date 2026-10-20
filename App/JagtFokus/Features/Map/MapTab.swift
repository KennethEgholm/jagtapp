import SwiftUI

/// Kort: the basemap full-bleed down to the tab bar, below a system navigation bar.
/// Boundaries and the status card live here; saved areas come in a later slice.
///
/// The camera moves only on explicit events: the start, the first exact GPS fix when
/// the user has not touched the map, and `fly(to:)`. Later GPS fixes and a new place on
/// Jagtbart never move it.
struct MapTab: View {
    @Environment(SeasonStore.self) private var store
    @Environment(MapStore.self) private var map
    @State private var request: MapCameraRequest?
    /// The camera is settled: the user moved it, the start was already exact, or the GPS fix has been used.
    @State private var settled = false
    @State private var followRequest = 0
    @State private var accuracyRequest = 0
    @State private var reducedAccuracy = false
    @State private var showInfo = false

    var body: some View {
        NavigationStack {
            ParcelMapView(
                initialCamera: startCamera,
                request: request,
                followRequest: followRequest,
                accuracyRequest: accuracyRequest,
                onReducedAccuracy: { reducedAccuracy = $0 },
                onUserMove: { settled = true },
                parcels: map.visibleParcels,
                saveFrame: nil,
                onRegionChange: { box, zoom in map.regionChanged(box, zoom: zoom) }
            )
            .ignoresSafeArea(edges: .bottom)
            .safeAreaInset(edge: .bottom) {
                MapStatusCard(
                    live: map.live,
                    savedAreaText: savedAreaText,
                    reducedAccuracy: reducedAccuracy,
                    onUsePrecise: { accuracyRequest += 1 }
                )
            }
            .navigationTitle(Copy.mapTab)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        // The button is an explicit ask, so it ends the wait for the first fix too.
                        settled = true
                        followRequest += 1
                    } label: {
                        Label(Copy.mapCenterOnMe, systemImage: "location")
                    }
                    Button {
                        showInfo = true
                    } label: {
                        Label(Copy.mapInfoTitle, systemImage: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showInfo) { MapInfoSheet() }
        }
        .onAppear {
            // The map has just started at the best camera there is. An exact fix or `-map` needs no flight.
            if exactFix != nil || debugCamera != nil { settled = true }
            #if DEBUG
            if UserDefaults.standard.string(forKey: "sheet") == "mapinfo" { showInfo = true }
            #endif
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

    /// "Gemt område: Område 1, hentet 20. okt 2026".
    private var savedAreaText: String? {
        guard let area = map.areaInView else { return nil }
        return Copy.savedArea(name: area.name, downloaded: store.calendar.shortWithYear(area.savedAt))
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

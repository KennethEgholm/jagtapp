import SwiftUI

/// Kort: the basemap full-bleed down to the tab bar, below a system navigation bar.
/// Boundaries, the status card and the saved areas live here.
///
/// The camera moves only on explicit events: the start, the first exact GPS fix when
/// the user has not touched the map (MapLibre's raw position, not the geocoded place), and `fly(to:)`. Later GPS fixes and a new place on
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
    @State private var showSaved = false
    @State private var askName = false
    @State private var draftName = ""
    @State private var tappedParcel: Parcel?

    var body: some View {
        NavigationStack {
            ParcelMapView(
                initialCamera: startCamera,
                request: request,
                followRequest: followRequest,
                accuracyRequest: accuracyRequest,
                onReducedAccuracy: { reducedAccuracy = $0 },
                onUserMove: { settled = true },
                onUserLocation: { firstFix($0) },
                parcels: map.visibleParcels,
                saveFrame: map.saveFrame,
                onCentreChange: { map.centreMoved(to: $0) },
                onRegionChange: { box, zoom in map.regionChanged(box, zoom: zoom) },
                onParcelTap: { id in tappedParcel = map.parcel(withId: id) }
            )
            .ignoresSafeArea(edges: .bottom)
            .safeAreaInset(edge: .bottom) {
                MapStatusCard(
                    live: map.live,
                    saving: map.saving,
                    savedAreaText: savedAreaText,
                    reducedAccuracy: reducedAccuracy,
                    savedUnreadable: map.savedAreasUnreadable,
                    onUsePrecise: { accuracyRequest += 1 },
                    onSave: {
                        draftName = map.index.nextDefaultName(prefix: Copy.mapAreaPrefix)
                        askName = true
                    },
                    onCancelSave: { map.cancelSave() }
                )
            }
            .navigationTitle(Copy.mapTab)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSaved = true
                    } label: {
                        Label(Copy.mapSavedAreas, systemImage: "square.stack.3d.down.right")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        map.beginSave()
                    } label: {
                        Label(Copy.mapSaveArea, systemImage: "square.and.arrow.down")
                    }
                    .disabled(!map.canSave)
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
            .sheet(item: $tappedParcel) { ParcelDetailsView(parcel: $0) }
            .sheet(isPresented: $showSaved) {
                SavedAreasView { area in
                    settled = true
                    fly(to: MapCamera(center: area.box.center, zoom: MapRules.boundaryMinZoom))
                }
            }
            .alert(Copy.mapSaveArea, isPresented: $askName) {
                TextField("Navn", text: $draftName)
                Button("Gem") {
                    let name = draftName
                    Task { await map.save(name: name) }
                }
                Button("Annuller", role: .cancel) {}
            }
        }
        .task {
            await map.start()
            #if DEBUG
            await runDebugSave()
            #endif
            // Online: a pack saved with an older week's tile URL is downloaded again.
            await map.refreshStaleBasemaps()
            #if DEBUG
            await runDebugParcel()
            #endif
        }
        .onAppear {
            // The map has just started at the best camera there is. An exact fix or `-map` needs no flight.
            if exactFix != nil || debugCamera != nil { settled = true }
            #if DEBUG
            if UserDefaults.standard.string(forKey: "sheet") == "mapinfo" { showInfo = true }
            if UserDefaults.standard.string(forKey: "sheet") == "saved" { showSaved = true }
            #endif
        }
        .onChange(of: exactFix) { _, fix in
            if let fix { firstFix(fix) }
        }
    }

    /// The first position, from the puck or from Jagtbart's fix, whichever comes first. The puck
    /// needs no geocoding, so offline in the field the map still starts where the hunter is.
    /// Only while the camera is not settled: no gesture, no `-map`, no earlier fix.
    private func firstFix(_ point: Coordinate) {
        guard !settled, debugCamera == nil else { return }
        settled = true
        fly(to: MapCamera.start(at: point, isExact: true))
    }

    #if DEBUG
    /// DEBUG `-save choosing|alert|go|delete|reset`: choose the frame, ask for a name, save at once, delete the newest area, or reset all saved areas.
    private func runDebugSave() async {
        guard let step = UserDefaults.standard.string(forKey: "save") else { return }
        if step == "reset" {
            await map.resetSavedAreas()
            return
        }
        if step == "delete" {
            if let first = map.index.areas.first { await map.delete(first.id) }
            return
        }
        map.beginSave()
        switch step {
        case "alert":
            draftName = map.index.nextDefaultName(prefix: Copy.mapAreaPrefix)
            askName = true
        case "go":
            await map.save(name: "")
        default:
            break
        }
    }
    #endif

    #if DEBUG
    /// DEBUG `-parcel <matrikelnummer>`: open the parcel sheet once the view has its parcels.
    private func runDebugParcel() async {
        guard let number = UserDefaults.standard.string(forKey: "parcel") else { return }
        for _ in 0..<50 {
            if let parcel = map.parcel(number: number) {
                tappedParcel = parcel
                return
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }
    #endif

    /// For the saved-area rows.
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

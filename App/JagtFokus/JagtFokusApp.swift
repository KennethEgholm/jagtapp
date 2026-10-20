import SwiftUI

@main
struct JagtFokusApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = SeasonStore()
    @State private var bag = BagStore()
    @State private var map = MapStore()

    init() {
        // Also called by every MapLibre entry point, so the order of initialisers does not matter.
        MapRequestProtocol.install()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(bag)
                .environment(map)
                .task {
                    await map.start()
                    // A new OpenFreeMap week is fetched for the saved areas while there is a network,
                    // not only when Kort is opened: in the field there may be none.
                    await map.refreshStaleBasemaps()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await map.refreshStaleBasemaps() }
        }
    }
}

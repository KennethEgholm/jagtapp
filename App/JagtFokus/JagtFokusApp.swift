import SwiftUI

@main
struct JagtFokusApp: App {
    @State private var store = SeasonStore()
    @State private var bag = BagStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(bag)
        }
    }
}

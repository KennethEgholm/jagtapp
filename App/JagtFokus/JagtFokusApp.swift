import SwiftUI

@main
struct JagtFokusApp: App {
    @State private var store = SeasonStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}

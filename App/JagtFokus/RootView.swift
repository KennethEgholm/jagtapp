import SwiftUI
import UIKit

struct RootView: View {
    @Environment(SeasonStore.self) private var store
    @Environment(BagStore.self) private var bag
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("harGodkendtFraskrivelse") private var acceptedDisclaimer = false
    @AppStorage("udseende") private var appearance: Appearance = .system
    @State private var tab: AppTab = .today

    enum AppTab: Hashable {
        case today, bag, all, settings
    }

    var body: some View {
        Group {
            if acceptedDisclaimer {
                TabView(selection: $tab) {
                    Tab(Copy.todayTab, systemImage: "scope", value: AppTab.today) {
                        TodayView()
                    }
                    Tab(Copy.bagTab, systemImage: "book.closed", value: AppTab.bag) {
                        BagTabView()
                    }
                    Tab("Alle arter", systemImage: "list.bullet", value: AppTab.all) {
                        AllSpeciesView()
                    }
                    Tab("Indstillinger", systemImage: "gearshape", value: AppTab.settings) {
                        SettingsView()
                    }
                }
                .transition(.opacity)
            } else {
                WelcomeView {
                    withAnimation(.easeInOut) { acceptedDisclaimer = true }
                }
                .transition(.opacity)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            store.refreshNow()
            if acceptedDisclaimer { store.requestLocationIfNeeded() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            store.refreshNow()
        }
        .onChange(of: appearance) { _, new in new.apply() }
        .onChange(of: bag.tabRequests) { _, _ in tab = .bag }
        .sensoryFeedback(.success, trigger: bag.saves)
        .environment(\.locale, AppLanguage.locale)
        .onAppear {
            appearance.apply()
            applyLaunchTab()
        }
    }

    /// Debug only: `-tab bag|all|settings` for screenshots. `about` is the same tab as settings.
    private func applyLaunchTab() {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "tab") {
        case "bag", "nedlagt": tab = .bag
        case "all": tab = .all
        case "settings", "about": tab = .settings
        default: break
        }
        #endif
    }
}

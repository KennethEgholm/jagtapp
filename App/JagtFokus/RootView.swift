import SwiftUI
import UIKit

struct RootView: View {
    @Environment(SeasonStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("harGodkendtFraskrivelse") private var acceptedDisclaimer = false
    @AppStorage("udseende") private var appearance: Appearance = .system
    @State private var tab: AppTab = .today

    enum AppTab: Hashable {
        case today, all, settings, about
    }

    var body: some View {
        Group {
            if acceptedDisclaimer {
                TabView(selection: $tab) {
                    Tab("Jagtbar", systemImage: "scope", value: AppTab.today) {
                        TodayView()
                    }
                    Tab("Alle arter", systemImage: "list.bullet", value: AppTab.all) {
                        AllSpeciesView()
                    }
                    Tab("Indstillinger", systemImage: "gearshape", value: AppTab.settings) {
                        SettingsView()
                    }
                    Tab("Om", systemImage: "info.circle", value: AppTab.about) {
                        AboutView()
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
        .onAppear {
            appearance.apply()
            applyLaunchTab()
        }
    }

    /// Debug only: `-tab all|settings|about` for screenshots.
    private func applyLaunchTab() {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "tab") {
        case "all": tab = .all
        case "settings": tab = .settings
        case "about": tab = .about
        default: break
        }
        #endif
    }
}

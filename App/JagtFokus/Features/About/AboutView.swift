import SwiftUI

/// Om, below the settings in the same tab: source, responsibility, Schweiss, photos, privacy and this app.
/// Sections only, so the disclaimer stays one tap away.
struct AboutSections: View {
    @Environment(SeasonStore.self) private var store

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Kilde")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(store.catalog.sourceName)
            }
            .accessibilityElement(children: .combine)
            LabeledContent("Opdateret", value: updatedText)
            if let remoteStatus = store.remoteStatus {
                LabeledContent("Data", value: remoteStatus)
            }
            if let url = store.catalog.sourceLink {
                Link(destination: url) {
                    Label("Åbn bekendtgørelsen", systemImage: "arrow.up.right.square")
                }
            }
        } header: {
            Text("Data")
        }

        Section {
            Text(Copy.disclaimer)
                .id("ansvar")
            Label(Copy.daylight, systemImage: "sun.horizon")
            Label(Copy.deerNote, systemImage: "map")
            Label(Copy.biologyDisclaimer, systemImage: "leaf")
            Label(Copy.parcelDisclaimer, systemImage: "square.dashed")
        } header: {
            Text("Ansvar")
        } footer: {
            Text(Copy.notTheLaw)
        }

        Section {
            NavigationLink {
                SchweissView()
            } label: {
                Label(Copy.schweissTitle, systemImage: "pawprint.fill")
            }
        } footer: {
            Text("Anskudt og påkørt hjortevildt.")
        }

        Section {
            Label("Artsfotos fra Wikimedia Commons", systemImage: "photo.on.rectangle")
            if let url = URL(string: "https://commons.wikimedia.org") {
                Link(destination: url) {
                    Label("Åbn Wikimedia Commons", systemImage: "arrow.up.right.square")
                }
            }
        } header: {
            Text("Fotos")
        } footer: {
            Text("Licenser: CC0, public domain, CC BY og CC BY-SA. Fotograf og licens står under hvert billede. Billederne er beskåret og skaleret.")
        }

        Section {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(Copy.mapParcels)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(verbatim: CadastreService.attribution)
            }
            .accessibilityElement(children: .combine)
            .id("kort")
            Link(destination: CadastreService.licenceURL) {
                Label("Licens", systemImage: "arrow.up.right.square")
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(Copy.mapBasemap)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(verbatim: OpenFreeMap.attribution)
            }
            .accessibilityElement(children: .combine)
            if let url = URL(string: "https://openfreemap.org") {
                Link(destination: url) {
                    Label("Åbn OpenFreeMap", systemImage: "arrow.up.right.square")
                }
            }
        } header: {
            Text("Kort")
        } footer: {
            Text("Kortet bruger MapLibre, som er open source.")
        }

        Section {
            Label("Ingen konto", systemImage: "person.crop.circle.badge.xmark")
                .id("privatliv")
            Label("Ingen tracking", systemImage: "hand.raised")
            Label("Positionen bruges kun til sted, sol og vejr", systemImage: "location")
            Label("Jagttiderne virker offline", systemImage: "wifi.slash")
            if let url = URL(string: "https://kennethegholm.github.io/jagtapp/privatliv.html") {
                Link(destination: url) {
                    Label("Åbn privatlivspolitikken", systemImage: "arrow.up.right.square")
                }
            }
        } header: {
            Text("Privatliv")
        } footer: {
            Text("Vejret hentes fra MET i Norge med din position afrundet til omkring en kilometer. Stednavnet slår Apple op. Vi får aldrig din position.")
        }

        Section("Denne app") {
            HStack(spacing: Spacing.s) {
                BrandMark(size: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("JagtFokus")
                        .font(.headline)
                    Text("Jagttider efter dato og sted")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, Spacing.xxs)
            .accessibilityElement(children: .combine)
            LabeledContent("Version", value: "\(appVersion) (\(appBuild))")
            LabeledContent("Dataversion", value: "v\(store.catalog.version)")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// "2026-10-11" → "11. oktober 2026"
    private var updatedText: String {
        guard let date = store.calendar.date(fromDayKey: store.catalog.updated) else {
            return store.catalog.updated
        }
        return store.calendar.fullWithYear(date)
    }
}

import SwiftUI

struct AboutView: View {
    @Environment(SeasonStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: Spacing.s) {
                        BrandMark(size: 88)
                        VStack(spacing: Spacing.xxs) {
                            Text("JagtFokus")
                                .font(.title2.weight(.bold))
                            Text("Jagttider efter dato og sted")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(versionText)
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xs)
                    .listRowBackground(Color.clear)
                    .accessibilityElement(children: .combine)
                }

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
                    if let url = URL(string: store.catalog.sourceURL) {
                        Link(destination: url) {
                            Label("Åbn bekendtgørelsen", systemImage: "arrow.up.right.square")
                        }
                    }
                } header: {
                    Text("Data")
                }

                Section {
                    Text(Copy.disclaimer)
                    Label(Copy.daylight, systemImage: "sun.horizon")
                    Label(Copy.deerNote, systemImage: "map")
                    Label(Copy.biologyDisclaimer, systemImage: "leaf")
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

                Section("Privatliv") {
                    Label("Ingen konto", systemImage: "person.crop.circle.badge.xmark")
                    Label("Ingen tracking", systemImage: "hand.raised")
                    Label("Din position bliver på telefonen", systemImage: "location")
                    Label("Virker offline", systemImage: "wifi.slash")
                }
            }
            .navigationTitle("Om")
        }
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build)) · data v\(store.catalog.version)"
    }

    /// "2026-10-11" → "11. oktober 2026"
    private var updatedText: String {
        let parts = store.catalog.updated.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return store.catalog.updated }
        return "\(store.calendar.danishFull(MonthDay(month: parts[1], day: parts[2]))) \(parts[0])"
    }
}

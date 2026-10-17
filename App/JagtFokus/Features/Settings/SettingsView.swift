import SwiftUI

/// The settings, then Om in the same list. One tab for both.
struct SettingsView: View {
    @AppStorage("udseende") private var appearance: Appearance = .system
    @AppStorage(Copy.collapseGroupsKey) private var collapseGroups = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Udseende", selection: $appearance) {
                        ForEach(Appearance.allCases) { option in
                            Label(option.title, systemImage: option.systemImage)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Udseende")
                } footer: {
                    Text("System følger telefonens indstilling for lys og mørk.")
                }

                Section {
                    Toggle(Copy.collapseGroupsTitle, isOn: $collapseGroups)
                } header: {
                    Text("Lister")
                } footer: {
                    Text(Copy.collapseGroupsFooter)
                }

                AboutSections()
            }
            .navigationTitle("Indstillinger")
        }
    }
}

#Preview {
    SettingsView()
        .environment(SeasonStore())
}

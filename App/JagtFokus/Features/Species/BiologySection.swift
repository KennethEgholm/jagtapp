import SwiftUI

/// Life-history notes on the species page. Below the hunting answer.
struct BiologySection: View {
    let biology: TaxonBiology

    var body: some View {
        Section {
            fact(label: String(localized: "Latinsk navn"), value: biology.latin, italic: true)
            ForEach(biology.facts) { item in
                fact(label: item.label, value: item.value, italic: false)
            }
            ForEach(biology.sources) { source in
                if let url = URL(string: source.url) {
                    Link(destination: url) {
                        Label(source.name, systemImage: "arrow.up.right.square")
                    }
                }
            }
        } header: {
            Text("Biologi")
        } footer: {
            Text(Copy.biologyDisclaimer)
        }
    }

    private func fact(label: String, value: String, italic: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .italic(italic)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

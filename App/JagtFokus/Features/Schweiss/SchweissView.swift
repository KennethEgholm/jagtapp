import SwiftUI

/// Info page for the official Schweiss register. No handler phone list:
/// that waits for permission from the secretariat. Views only format.
struct SchweissView: View {
    var body: some View {
        List {
            Section {
                ListHeading(title: Copy.schweissTitle)
            }
            .listSectionSpacing(.compact)

            Section {
                Text(Copy.schweissHuntDuty)
                siteLink(Copy.schweissFindHandler, url: SchweissURL.handlers, hint: "Åbner schweiss.dk")
                siteLink(Copy.schweissSource, url: SchweissURL.source, hint: "Åbner Naturstyrelsen")
            } header: {
                Text(Copy.schweissHuntHeading)
            } footer: {
                Text(Copy.schweissHuntFooter)
            }

            Section {
                callLink(
                    Copy.schweissCall1812,
                    url: SchweissURL.vagtcentral,
                    label: "Ring 1812, Dyrenes Beskyttelses Vagtcentral"
                )
            } header: {
                Text(Copy.schweissTrafficHeading)
            } footer: {
                Text(Copy.schweissTrafficFooter)
            }

            Section {
                Text(Copy.schweissAbout)
                Text(Copy.schweissReferral)
                siteLink(Copy.schweissAboutLink, url: SchweissURL.about, hint: "Åbner schweiss.dk")
                siteLink(Copy.schweissRules, url: SchweissURL.rules, hint: "Åbner schweiss.dk")
                siteLink(Copy.schweissExpect, url: SchweissURL.expect, hint: "Åbner schweiss.dk")
            } header: {
                Text(Copy.schweissAboutHeading)
            }

            Section {
                callLink(
                    Copy.schweissCallSecretariat,
                    url: SchweissURL.secretariat,
                    label: "Ring 93 59 70 80, Schweiss-sekretariatet"
                )
                siteLink(Copy.schweissSecretariatMail, url: SchweissURL.mail, systemImage: "envelope", hint: "Skriver til Schweiss-sekretariatet")
            } header: {
                Text(Copy.schweissSecretariatHeading)
            } footer: {
                Text(Copy.schweissSecretariatFooter)
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, Spacing.xs, for: .scrollContent)
        .scrollRevealedTitle(Copy.schweissTitle)
    }

    @ViewBuilder
    private func siteLink(_ title: String, url: URL?, systemImage: String = "arrow.up.right.square", hint: String) -> some View {
        if let url {
            Link(destination: url) {
                Label(title, systemImage: systemImage)
            }
            .accessibilityHint(hint)
        }
    }

    @ViewBuilder
    private func callLink(_ title: String, url: URL?, label: String) -> some View {
        if let url {
            Link(destination: url) {
                Label(title, systemImage: "phone.fill")
            }
            .accessibilityLabel(label)
        }
    }
}

/// Sheet from Jagtbart. Om pushes `SchweissView` itself.
struct SchweissSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SchweissView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(Copy.schweissClose) { dismiss() }
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }
}

private enum SchweissURL {
    static let handlers = URL(string: "https://schweiss.dk/hundeforere")
    static let source = URL(string: "https://naturstyrelsen.dk/aktiviteter-i-naturen/vildtforvaltning/tilskadekommet-vildt/schweisshunde")
    static let about = URL(string: "https://schweiss.dk/om-registret")
    static let rules = URL(string: "https://schweiss.dk/regler")
    static let expect = URL(string: "https://schweiss.dk/hvad-kan-jeg-forvente-af-en-legitimeret-schweisshundefoerer")
    static let vagtcentral = URL(string: "tel:1812")
    static let secretariat = URL(string: "tel:93597080")
    static let mail = URL(string: "mailto:schweiss@nst.dk")
}

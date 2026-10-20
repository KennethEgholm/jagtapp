import SwiftUI

/// A tap on a parcel: the cadastral facts the service sent. Display only, not a survey.
struct ParcelDetailsView: View {
    let parcel: Parcel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(Copy.parcelNumber, parcel.number)
                    if !parcel.district.isEmpty {
                        row(Copy.parcelDistrict, parcel.district)
                    }
                    if let code = parcel.districtCode {
                        row(Copy.parcelDistrictCode, String(code))
                    }
                    if let area = parcel.area {
                        row(Copy.parcelArea, areaText(area))
                    }
                } footer: {
                    Text(Copy.parcelDisclaimer)
                }
            }
            .navigationTitle(Copy.parcelTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Luk") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent {
            Text(value)
                .font(.body.weight(.semibold))
        } label: {
            Text(title)
        }
        .accessibilityElement(children: .combine)
    }

    /// Square metres up to a hectare, then hectares, with the app's language.
    private func areaText(_ squareMetres: Int) -> String {
        if squareMetres >= 10_000 {
            let hectares = Double(squareMetres) / 10_000
            let number = hectares.formatted(.number.precision(.fractionLength(1)).locale(AppLanguage.locale))
            return "\(number) ha"
        }
        return "\(squareMetres.formatted(.number.locale(AppLanguage.locale))) m²"
    }
}

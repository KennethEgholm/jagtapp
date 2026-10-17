import SwiftUI

/// First start. Explains the app and the disclaimer, and primes the location prompt.
/// "Forstået" is required before the list (spec/v1.md).
struct WelcomeView: View {
    var onAccept: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    BrandMark(size: 76)
                    Text("Velkommen til JagtFokus")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Se hvad der er jagtbart i dag, der hvor du er.")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.top, Spacing.xl)

                VStack(alignment: .leading, spacing: Spacing.l) {
                    Feature(
                        systemImage: "calendar.badge.clock",
                        title: String(localized: "Dato og sted"),
                        text: String(localized: "Listen følger dagens dato og din position. Du kan vælge en anden dag og et andet sted.")
                    )
                    Feature(
                        systemImage: "mappin.and.ellipse",
                        title: String(localized: "Lokale jagttider"),
                        text: String(localized: "Øer og områder med egne tider slår de generelle.")
                    )
                    Feature(
                        systemImage: "lock.shield",
                        title: String(localized: "Privat og offline"),
                        text: String(localized: "Ingen konto. Ingen tracking. Din position bliver på telefonen.")
                    )
                }

                VStack(alignment: .leading, spacing: Spacing.s) {
                    Label("Vigtigt", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.brandGold)
                    Text(Copy.disclaimer)
                    Text(Copy.daylight)
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .padding(Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                        .strokeBorder(Color.brandGold.opacity(0.35), lineWidth: 1)
                }
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.s) {
                Button(action: onAccept) {
                    Text("Forstået")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xxs)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(.brandGold)
                .foregroundStyle(Color.brandDeep)
                Text("Derefter spørger JagtFokus om din position.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.xs)
            .background {
                LinearGradient(
                    colors: [Color.brandDeep.opacity(0), Color.brandDeep],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }
        }
        .background {
            ZStack {
                Color.brandDeep
                RadialGradient(
                    colors: [Color(red: 0.13, green: 0.30, blue: 0.20).opacity(0.9), .clear],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 520
                )
            }
            .ignoresSafeArea()
        }
        .environment(\.colorScheme, .dark)
    }
}

private struct Feature: View {
    let systemImage: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.brandGold)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomeView {}
}

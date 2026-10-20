import SwiftUI

/// What the map says about its boundaries under the map: zoom in, loading, offline, a saved
/// area. A solid card, not glass: it is content. Every line has an icon and text.
struct MapStatusCard: View {
    let live: MapStore.Live
    /// Saving an area replaces the status with the save card.
    var saving: MapStore.Saving = .idle
    /// "Gemt område: …", when the view lies inside a saved area.
    let savedAreaText: String?
    let reducedAccuracy: Bool
    /// The index of saved areas cannot be read: saving is off, and Gemte områder offers a reset.
    var savedUnreadable = false
    let onUsePrecise: () -> Void
    var onSave: () -> Void = {}
    var onCancelSave: () -> Void = {}

    var body: some View {
        if saving != .idle {
            card { saveContent }
        } else if !statusLines.isEmpty || savedUnreadable || reducedAccuracy {
            card {
                ForEach(statusLines, id: \.text) { lineView($0) }
                if savedUnreadable { Label(Copy.mapSavedUnreadable, systemImage: "exclamationmark.triangle") }
                if reducedAccuracy { accuracy }
            }
        }
    }

    private struct Line {
        var text: String
        var systemImage: String?
    }

    /// Zoom first: below it nothing is drawn, saved areas included. Offline inside a saved
    /// area says both: that there is no network, and which area it is and when it was downloaded.
    private var statusLines: [Line] {
        let saved = savedAreaText.map { Line(text: $0, systemImage: "arrow.down.circle") }
        switch live {
        case .tooFarOut:
            return [Line(text: Copy.mapTooFarOut, systemImage: "plus.magnifyingglass")]
        case .offline:
            return [Line(text: Copy.mapOffline, systemImage: "wifi.slash")] + (saved.map { [$0] } ?? [])
        case .loading:
            return [Line(text: Copy.mapLoading, systemImage: nil)]
        case .idle, .loaded, .failed, .noKey:
            if let saved { return [saved] }
            switch live {
            case .failed: return [Line(text: Copy.mapFailed, systemImage: "exclamationmark.triangle")]
            case .noKey: return [Line(text: Copy.mapNoKey, systemImage: "lock.slash")]
            default: return []
            }
        }
    }

    @ViewBuilder
    private func lineView(_ line: Line) -> some View {
        if let systemImage = line.systemImage {
            Label(line.text, systemImage: systemImage)
        } else {
            // The spinner is the icon while loading.
            Label {
                Text(line.text)
            } icon: {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private var saveContent: some View {
        switch saving {
        case .choosing:
            Label(Copy.mapSaveFrame, systemImage: "square.dashed")
            ViewThatFits(in: .horizontal) {
                HStack { saveButton; cancelButton }
                VStack(alignment: .leading) { saveButton; cancelButton }
            }
        case .downloading(let name, let progress):
            Label(Copy.mapSaving(name: name), systemImage: "arrow.down.circle")
            ProgressView(value: progress)
            cancelButton
        case .saved(let name):
            Label(Copy.mapSaved(name: name), systemImage: "checkmark.circle")
        case .failed:
            Label(Copy.mapSaveFailed, systemImage: "exclamationmark.triangle")
            Button("Luk", action: onCancelSave)
                .buttonStyle(.bordered)
        case .idle:
            EmptyView()
        }
    }

    private var saveButton: some View {
        Button("Gem", action: onSave)
            .buttonStyle(.borderedProminent)
    }

    private var cancelButton: some View {
        Button("Annuller", action: onCancelSave)
            .buttonStyle(.bordered)
    }

    private var accuracy: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label(Copy.mapReducedAccuracy, systemImage: "location.slash")
            Button(Copy.mapUsePrecise, action: onUsePrecise)
                .buttonStyle(.bordered)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            content()
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .strokeBorder(.separator, lineWidth: 1)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.bottom, Spacing.xs)
        .accessibilityElement(children: .contain)
    }
}

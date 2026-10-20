import SwiftUI

/// Gemte områder: the areas saved for use without a network. Tap flies to one, swipe deletes.
struct SavedAreasView: View {
    @Environment(SeasonStore.self) private var store
    @Environment(MapStore.self) private var map
    @Environment(\.dismiss) private var dismiss
    /// Called after the sheet has closed.
    let onSelect: (OfflineArea) -> Void
    @State private var confirmReset = false

    var body: some View {
        @Bindable var map = map
        NavigationStack {
            Group {
                if map.savedAreasUnreadable {
                    List {
                        Section {
                            Label(Copy.mapSavedUnreadable, systemImage: "exclamationmark.triangle")
                            Button(Copy.mapResetSaved, role: .destructive) { confirmReset = true }
                        }
                    }
                } else if map.index.areas.isEmpty {
                    ContentUnavailableView(Copy.mapNoSavedAreas, systemImage: "square.stack.3d.down.right")
                } else {
                    List {
                        ForEach(map.index.areas) { area in
                            Button {
                                dismiss()
                                onSelect(area)
                            } label: {
                                row(area)
                            }
                            .tint(.primary)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await map.delete(area.id) }
                                } label: {
                                    Label("Slet", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .confirmationDialog(Copy.mapResetWarning, isPresented: $confirmReset, titleVisibility: .visible) {
                Button(Copy.mapResetSaved, role: .destructive) {
                    Task { await map.resetSavedAreas() }
                }
                Button("Annuller", role: .cancel) {}
            }
            .alert(Copy.mapDeleteFailed, isPresented: $map.deleteFailed) {}
            .alert(Copy.mapResetFailed, isPresented: $map.resetFailed) {}
            .navigationTitle(Copy.mapSavedAreas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Luk") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(_ area: OfflineArea) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(area.name)
                .font(.headline)
            Text(Copy.mapDownloaded(date: store.calendar.shortWithYear(area.savedAt), size: size(area.bytes)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func size(_ bytes: Int) -> String {
        Int64(bytes).formatted(.byteCount(style: .file).locale(AppLanguage.locale))
    }
}

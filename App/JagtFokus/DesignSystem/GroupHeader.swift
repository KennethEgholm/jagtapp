import SwiftUI

/// A species group's row on Jagtbart and Alle arter: sketch, name, count, and a chevron when it folds.
struct GroupHeader: View {
    let group: ResolvedGroup
    /// Nil when the group does not fold.
    var expanded: Bool?

    var body: some View {
        HStack(spacing: Spacing.xs) {
            GroupSketch(groupId: group.id)
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .layoutPriority(1)
            Spacer(minLength: Spacing.xs)
            Text("\(group.species.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if let expanded {
                FoldChevron(expanded: expanded)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel([title, Copy.speciesCount(group.species.count)].joined(separator: ", "))
    }

    private var title: String {
        Copy.groupTitle(id: group.id, fromData: group.title)
    }
}

/// Down when shut, up when open.
struct FoldChevron: View {
    let expanded: Bool

    var body: some View {
        Image(systemName: "chevron.down")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .rotationEffect(.degrees(expanded ? 180 : 0))
            .accessibilityHidden(true)
    }
}

/// A row that folds its section open or shut.
struct FoldButton<Label: View>: View {
    let expanded: Bool
    let hint: LocalizedStringKey
    let toggle: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button {
            withAnimation { toggle() }
        } label: {
            label
        }
        .tint(.primary)
        .accessibilityValue(Copy.showState(expanded))
        .accessibilityHint(hint)
    }
}

enum GroupFolding {
    /// Debug only: `-groups open` on this launch. A leftover UserDefaults value must not keep groups open.
    static var launchOpensAll: Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-groups"), index + 1 < args.count else { return false }
        return args[index + 1] == "open"
    }
}

extension Set {
    mutating func toggle(_ member: Element) {
        if contains(member) {
            remove(member)
        } else {
            insert(member)
        }
    }
}

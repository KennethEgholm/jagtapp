import SwiftUI

/// A species group's row on Jagtbart and Alle arter: sketch, name, count, and a chevron when it folds.
struct GroupHeader: View {
    let group: ResolvedGroup
    /// Nil when the group does not fold.
    var expanded: Bool?
    /// Open species with their last day within a week. Jagtbart only: Alle arter shows no status.
    var closingSoon = 0

    var body: some View {
        HStack(spacing: Spacing.xs) {
            GroupSketch(groupId: group.id)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                // Visible while the group is shut, so the warning on the answer card can be found.
                if closingSoon > 0 {
                    Text("\(Image(systemName: "hourglass")) \(Copy.closingSoon(closingSoon))")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.seasonClosingSoon)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: Spacing.xs)
            Text("\(group.species.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                // The name and the warning wrap. The count never splits.
                .fixedSize()
            if let expanded {
                FoldChevron(expanded: expanded)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spoken)
    }

    private var title: String {
        Copy.groupTitle(id: group.id, fromData: group.title)
    }

    private var spoken: String {
        var parts = [title, Copy.speciesCount(group.species.count)]
        if closingSoon > 0 {
            parts.append(Copy.closingSoon(closingSoon))
        }
        return parts.joined(separator: ", ")
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

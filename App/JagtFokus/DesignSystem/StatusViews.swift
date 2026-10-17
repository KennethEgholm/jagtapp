import SwiftUI

/// "Lokal jagttid" in brass.
struct LocalBadge: View {
    var body: some View {
        Label("Lokal jagttid", systemImage: "mappin.and.ellipse")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.localTime)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 3)
            .background(Color.localTime.opacity(0.14), in: Capsule())
    }
}

/// Compact trailing status for a list row.
struct SeasonStatusText: View {
    let status: SeasonStatus
    let calendar: SeasonCalendar

    var body: some View {
        Group {
            if status.isOpen, let end = status.endDate {
                if status.isClosingSoon {
                    Label(status.daysLeft == 0 ? "Sidste dag" : "Sidste dag \(short(end))", systemImage: "hourglass")
                        .foregroundStyle(.seasonClosingSoon)
                        .fontWeight(.semibold)
                } else {
                    Text("til \(short(end))")
                        .foregroundStyle(.secondary)
                }
            } else if let next = status.nextOpening {
                Text("åbner \(short(next))")
                    .foregroundStyle(.secondary)
            } else {
                Text("Ingen jagttid")
                    .foregroundStyle(.secondary)
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    }

    private func short(_ date: Date) -> String {
        calendar.short(calendar.monthDay(on: date))
    }
}

enum StatusCopy {
    /// "i dag", "i morgen", "om 21 dage"
    static func relative(days: Int) -> String {
        switch days {
        case 0: String(localized: "i dag")
        case 1: String(localized: "i morgen")
        default: String(localized: "om \(days) dage")
        }
    }

    static func spoken(_ status: SeasonStatus, calendar: SeasonCalendar) -> String {
        if status.isOpen, let end = status.endDate, let left = status.daysLeft {
            let last = String(localized: "sidste dag \(calendar.full(calendar.monthDay(on: end)))")
            return left == 0 ? String(localized: "Jagtbar, sidste dag") : String(localized: "Jagtbar, \(last)")
        }
        if let next = status.nextOpening {
            return String(localized: "Ikke jagtbar, åbner \(calendar.full(calendar.monthDay(on: next)))")
        }
        return String(localized: "Ingen jagttid")
    }
}

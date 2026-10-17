import SwiftUI

struct DatePickerSheet: View {
    @Environment(SeasonStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var initialDate: Date
    var onSelect: (Date) -> Void
    @State private var draft = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.xs) {
                            ForEach(quickPicks, id: \.title) { pick in
                                Button(pick.title) {
                                    onSelect(pick.date)
                                    dismiss()
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                            }
                        }
                        .padding(.horizontal)
                    }

                    DatePicker("Dato", selection: $draft, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.calendar, store.calendar.calendar)
                        .environment(\.timeZone, store.calendar.calendar.timeZone)
                        .padding(.horizontal)
                }
                .padding(.top, Spacing.xs)
            }
            .navigationTitle("Vælg dag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuller") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Vælg") {
                        onSelect(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { draft = initialDate }
        }
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
    }

    /// I dag, I morgen and the coming weekend: the days hunters plan for.
    private var quickPicks: [(title: String, date: Date)] {
        let cal = store.calendar.calendar
        let today = cal.startOfDay(for: store.now)
        var picks: [(String, Date)] = [(String(localized: "I dag"), today)]
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: today) {
            picks.append((String(localized: "I morgen"), tomorrow))
        }
        for (weekday, name) in [(7, String(localized: "Lørdag")), (1, String(localized: "Søndag"))] {
            if let next = cal.nextDate(after: today, matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime),
               cal.dateComponents([.day], from: today, to: next).day ?? 0 > 1 {
                let day = store.calendar.short(store.calendar.monthDay(on: next))
                picks.append((String(localized: "\(name) \(day)"), next))
            }
        }
        return picks.map { (title: $0.0, date: $0.1) }
    }
}

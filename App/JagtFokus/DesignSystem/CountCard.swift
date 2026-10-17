import SwiftUI

/// A big number with a line of text beside it. Jagtbart's answer and the journal's year total.
struct CountCard<Detail: View>: View {
    let count: Int
    let title: String
    @ViewBuilder var detail: Detail

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            Text("\(count)")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(count > 0 ? Color.seasonOpen : Color.secondary)
                .contentTransition(.numericText())
                .frame(minWidth: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                detail
                    .font(.subheadline)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.xxs)
        .listRowBackground(Color.seasonOpen.opacity(count > 0 ? 0.12 : 0.05))
        .animation(.snappy, value: count)
        .accessibilityElement(children: .combine)
    }
}

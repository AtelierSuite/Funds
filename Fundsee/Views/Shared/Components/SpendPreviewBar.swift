import SwiftUI

struct SpendPreviewBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var used: Decimal
    var pending: Decimal
    var budget: Decimal
    var tint: Color = .accentColor

    private var over: Bool { used + pending > budget }

    private var remaining: Decimal { budget - used - pending }

    private func fraction(_ value: Decimal) -> Double {
        guard budget > 0 else { return value > 0 ? 1 : 0 }
        return min(1, max(0, value.doubleValue / budget.doubleValue))
    }

    private var remainingLabel: String {
        let value = abs(remaining).currencyString
        switch (pending > 0, remaining < 0) {
        case (false, false):
            return String(localized: "SpendInput.Remaining.Left", defaultValue: "\(value) left")
        case (false, true):
            return String(localized: "SpendInput.Remaining.Over", defaultValue: "\(value) over")
        case (true, false):
            return String(localized: "SpendInput.Remaining.LeftAfter", defaultValue: "\(value) left after this")
        case (true, true):
            return String(localized: "SpendInput.Remaining.OverAfter", defaultValue: "\(value) over after this")
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let color = over ? Color.red : tint
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.18))
                    Capsule()
                        .fill(color.opacity(0.4))
                        .frame(width: proxy.size.width * fraction(used + pending))
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: proxy.size.width * fraction(used))
                }
            }
            .frame(height: 10)

            let labelLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout())
            labelLayout {
                Text(used.currencyString)
                    .foregroundStyle(.secondary)
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                }
                Text(remainingLabel)
                    .foregroundStyle(remaining < 0 ? Color.red : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .contentTransition(.numericText())
        }
        .animation(.smooth, value: pending)
    }
}

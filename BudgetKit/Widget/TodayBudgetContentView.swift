import SwiftUI
import WidgetKit

struct TodayBudgetContentView: View {
    let entry: BudgetEntry
    let family: WidgetFamily

    private static let lime = Color(red: 0.65, green: 0.86, blue: 0.13)

    var body: some View {
        switch family {
        case .accessoryInline:
            if entry.overBudget {
                Text(String(localized: "Widget.Inline.Over", defaultValue: "\((-entry.remaining).currencyString) over today"))
            } else {
                Text(String(localized: "Widget.Inline.Left", defaultValue: "\(entry.remaining.currencyString) left today"))
            }

        case .accessoryCircular:
            Gauge(value: entry.fractionUsed) {
                Image(systemName: "chart.pie.fill")
            } currentValueLabel: {
                Text(
                    (entry.overBudget ? -entry.remaining : entry.remaining).doubleValue,
                    format: .number.notation(.compactName).precision(.significantDigits(2))
                )
                .minimumScaleFactor(0.6)
            }
            .gaugeStyle(.accessoryCircular)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Widget.Title")
                    .font(.headline)
                if entry.overBudget {
                    Text(String(localized: "Widget.Rectangular.Over", defaultValue: "\((-entry.remaining).currencyString) over"))
                } else {
                    Text(String(localized: "Widget.Rectangular.Left", defaultValue: "\(entry.remaining.currencyString) left"))
                }
                Gauge(value: entry.fractionUsed) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
            }

        case .systemMedium:
            HStack(spacing: 16) {
                ring
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.categories.prefix(4)) { category in
                        HStack(spacing: 6) {
                            Image(systemName: category.iconName)
                                .font(.caption)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(CategoryIconPalette.color(for: category.iconName))
                                .frame(width: 18)
                            Text(category.name)
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer()
                            Text(category.used.compactCurrencyString)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(category.used > category.amount ? .red : .primary)
                        }
                    }
                }
            }

        default:
            ring
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
            Circle()
                .trim(from: 0, to: entry.fractionUsed)
                .stroke(
                    entry.overBudget ? Color.red : Self.lime,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text(entry.overBudget ? LocalizedStringKey("Widget.Ring.Over") : LocalizedStringKey("Widget.Ring.Left"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text((entry.overBudget ? -entry.remaining : entry.remaining).compactCurrencyString)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
        }
        .padding(4)
    }
}

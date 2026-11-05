import SwiftUI

struct CategoryGridCell: View {
    static let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    static let spacing: CGFloat = 10

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .subheadline) private var slashHeight = 10.5

    let category: CategorySnapshot

    private var labelColor: Color {
        colorScheme == .light ? category.iconColor.mix(with: .black, by: 0.55) : .white
    }

    private var spentText: some View {
        Text(category.used.compactCurrencyString)
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(labelColor)
            .contentTransition(.numericText())
    }

    private var budgetText: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            ValueSlash()
                .stroke(labelColor.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: slashHeight * 0.45, height: slashHeight)
                .padding(.horizontal, 1)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
            Text(category.amount.compactCurrencyString)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(labelColor.opacity(0.6))
        }
    }

    var body: some View {
        let over = category.used > category.amount
        let fraction = category.amount > 0
            ? min(1, category.used.doubleValue / category.amount.doubleValue)
            : (category.used > 0 ? 1 : 0)
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: category.iconName)
                .font(.system(size: 20))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(labelColor)
                .frame(height: 26)
            Text(category.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(labelColor.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            let valueLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 2))
            valueLayout {
                spentText
                budgetText
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(category.iconColor.gradient)
                        .opacity(colorScheme == .light ? 0.22 : 0.3)
                    Rectangle()
                        .fill(category.iconColor.gradient)
                        .opacity(colorScheme == .light ? 0.5 : 1)
                        .frame(width: proxy.size.width * fraction)

                    if over {
                        RadialGradient(
                            colors: [Color.red.opacity(0.85), .clear],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: max(proxy.size.width, proxy.size.height) * 0.75
                        )
                    }
                }
            }
        }
        .compositingGroup()
        .clipShape(.rect(cornerRadius: 22))
        .shadow(
            color: colorScheme == .light ? category.iconColor.opacity(0.35) : .clear,
            radius: 6, y: 3
        )
        .contentShape(.rect)
    }
}

private struct ValueSlash: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
    }
}

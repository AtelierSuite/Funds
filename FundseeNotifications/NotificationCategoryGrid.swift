import SwiftUI

struct NotificationCategoryGrid: View {
    let categories: [CategorySnapshot]

    var body: some View {
        if !categories.isEmpty {
            LazyVGrid(columns: CategoryGridCell.columns, spacing: CategoryGridCell.spacing) {
                ForEach(categories) { category in
                    CategoryGridCell(category: category)
                }
            }
            .padding(12)
        }
    }
}

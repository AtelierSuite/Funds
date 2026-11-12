import WidgetKit
import SwiftUI

@main
struct FundseeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayBudgetWidget()
        LogSpendingControl()
    }
}

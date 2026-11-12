import AppIntents
import SwiftUI
import WidgetKit

struct LogSpendingControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "LogSpendingControl") {
            ControlWidgetButton(action: QuickLogIntent()) {
                Label("Control.LogSpending.Title", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Control.LogSpending.Title")
        .description("Control.LogSpending.Description")
    }
}

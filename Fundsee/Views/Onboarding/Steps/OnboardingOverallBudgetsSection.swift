import SwiftData
import SwiftUI

struct OnboardingOverallBudgetsSection: View {
    private static let zeroPlaceholder = "0"

    @Query private var allSettings: [PlanSettings]

    var body: some View {
        if let settings = allSettings.primary {
            @Bindable var settings = settings
            Section {
                LabeledContent("Onboarding.Extras.Weekly") {
                    TextField(Self.zeroPlaceholder, value: $settings.weeklyOverallBudget, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Onboarding.Extras.Monthly") {
                    TextField(Self.zeroPlaceholder, value: $settings.monthlyOverallBudget, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Onboarding.Extras.Section.Header")
            } footer: {
                Text("Onboarding.Extras.Section.Footer")
            }
        }
    }
}

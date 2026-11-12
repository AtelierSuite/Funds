import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(BudgetStore.self) private var store

    @State private var spendTarget: SpendTarget?
    @State private var showingTemplatePicker = false
    @State private var showingQuickLog = false
    @State private var pickedTarget: SpendTarget?
    @State private var navigation = AppNavigation.shared
    @Namespace private var cardZoom

    private var engine: BudgetEngine { store.engine(around: today) }

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    var body: some View {
        NavigationStack {
            List {
                ringSection
                categoriesSection
                extraBudgetsSection
                changePlanSection
            }
            .listStyle(.plain)
            .navigationTitle(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
            .toolbarTitleDisplayMode(.inlineLarge)
            .sheet(isPresented: $showingTemplatePicker) {
                TemplateOverrideSheet(initialDate: today)
                    .navigationTransition(.zoom(sourceID: "changePlan", in: cardZoom))
            }
            .sheet(item: $spendTarget) { target in
                SpendInputSheet(
                    date: today,
                    categoryName: target.name,
                    categoryID: target.categoryID,
                    scope: target.scope,
                    period: target.period
                )
                .navigationTransition(.zoom(sourceID: target.name, in: cardZoom))
            }
            .sheet(isPresented: $showingQuickLog, onDismiss: presentPickedTarget) {
                QuickLogPickerSheet { target in
                    pickedTarget = target
                    showingQuickLog = false
                }
            }
            .onChange(of: navigation.quickLog, initial: true) { _, request in
                guard let request else { return }
                navigation.quickLog = nil
                handle(request)
            }
        }
    }

    private func handle(_ request: QuickLogRequest) {
        showingTemplatePicker = false
        let categories = engine.template(for: today)?.sortedCategories ?? []
        if let id = request.categoryID,
           let category = categories.first(where: { $0.uuid == id }) ?? categories.first(where: { $0.name == id }) {
            showingQuickLog = false
            spendTarget = SpendTarget(name: category.name, categoryID: category.uuid)
        } else {
            spendTarget = nil
            showingQuickLog = true
        }
    }

    private func presentPickedTarget() {
        guard let pickedTarget else { return }
        self.pickedTarget = nil
        spendTarget = pickedTarget
    }

    private var ringSection: some View {
        let engine = self.engine
        let budget = engine.effectiveBudget(for: today)
        let used = engine.spent(on: today)
        let template = engine.template(for: today)
        let carryover = engine.carryover == .nextDay ? budget - engine.baseBudget(for: today) : 0
        return Section {
            BudgetSummaryHeader(
                used: used,
                budget: budget,
                caption: String(localized: "Ring.Caption.Of", defaultValue: "of \(budget.currencyString)"),
                carryover: carryover,
                spendPalette: engine.spendPalette(on: today)
            ) {
                HStack(spacing: 8) {
                    Image(systemName: template?.iconName ?? "questionmark.circle")
                    if let template {
                        Text(template.name)
                    } else {
                        Text("Today.NoTemplate.Inline")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }

    private var categoriesSection: some View {
        let engine = self.engine
        let template = engine.template(for: today)
        return Section {
            if let template {
                LazyVGrid(columns: CategoryGridCell.columns, spacing: CategoryGridCell.spacing) {
                    ForEach(template.sortedCategories) { category in
                        let used = engine.spent(on: today, category: category)
                        Button {
                            spendTarget = SpendTarget(name: category.name, categoryID: category.uuid)
                        } label: {
                            CategoryGridCell(category: CategorySnapshot(category, used: used))
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: category.name, in: cardZoom)
                    }
                }
                .padding(.horizontal, 16)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            } else {
                ContentUnavailableView(
                    "Today.NoTemplate.Title",
                    systemImage: "square.dashed",
                    description: Text("Today.NoTemplate.Description")
                )
            }
        }
    }

    private var extraBudgetsSection: some View {
        Section {
            ExtraBudgetCards(engine: engine, date: today, namespace: cardZoom, spendTarget: $spendTarget)
                .padding(.horizontal, 16)
                .padding(.top, 10)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }

    private var changePlanSection: some View {
        Section {
            Button {
                showingTemplatePicker = true
            } label: {
                Text("Common.ChangeTemplate")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .matchedTransitionSource(id: "changePlan", in: cardZoom)
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }
}

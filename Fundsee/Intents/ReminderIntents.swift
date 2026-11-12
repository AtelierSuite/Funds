import AppIntents
import SwiftData

struct ReminderEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Intent.Parameter.Reminder")
    static let defaultQuery = ReminderEntityQuery()

    let id: String

    @Property(title: "Intent.Parameter.Time")
    var time: Date

    @Property(title: "Intent.Parameter.Message")
    var message: String

    @Property(title: "Intent.Parameter.Plan")
    var planName: String

    var displayRepresentation: DisplayRepresentation {
        let timeText = time.formatted(date: .omitted, time: .shortened)
        return DisplayRepresentation(
            title: LocalizedStringResource("Intent.Reminder.Title", defaultValue: "\(timeText), \(planName)"),
            subtitle: message.isEmpty ? nil : LocalizedStringResource("Intent.Verbatim", defaultValue: "\(message)"),
            image: .init(systemName: "bell.fill")
        )
    }

    init(_ reminder: TemplateReminder) {
        id = reminder.uuid
        self.time = Calendar.current.date(bySettingHour: reminder.hour, minute: reminder.minute, second: 0, of: .now) ?? .now
        self.message = reminder.message
        self.planName = reminder.template?.name ?? ""
    }
}

struct ReminderEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [ReminderEntity.ID]) async throws -> [ReminderEntity] {
        let ids = Set(identifiers)
        return Self.reminders().filter { ids.contains($0.uuid) }.map(ReminderEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [ReminderEntity] {
        Self.reminders().map(ReminderEntity.init)
    }

    @MainActor
    static func reminders(in plan: PlanEntity? = nil) -> [TemplateReminder] {
        IntentData.templates()
            .filter { plan == nil || $0.uuid == plan?.id }
            .flatMap(\.sortedReminders)
            .filter { !$0.uuid.isEmpty }
    }
}

extension IntentData {
    static func reminder(for entity: ReminderEntity) throws -> TemplateReminder {
        guard let reminder = ReminderEntityQuery.reminders().first(where: { $0.uuid == entity.id }) else {
            throw IntentDataError.reminderNotFound
        }
        return reminder
    }
}

struct GetRemindersIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.GetReminders.Title"
    static let description = IntentDescription("Intent.GetReminders.Description")

    @Parameter(title: "Intent.Parameter.Plan")
    var plan: PlanEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.GetReminders.Summary \(\.$plan)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[ReminderEntity]> & ProvidesDialog {
        let reminders = ReminderEntityQuery.reminders(in: plan).map(ReminderEntity.init)
        let list = reminders
            .map { "\($0.time.formatted(date: .omitted, time: .shortened)) (\($0.planName))" }
            .formatted(.list(type: .and))
        let dialog = reminders.isEmpty
            ? String(localized: "Intent.GetReminders.Dialog.None", defaultValue: "No reminders are set.")
            : String(localized: "Intent.GetReminders.Dialog", defaultValue: "Reminders: \(list).")
        return .result(value: reminders, dialog: IntentDialog(text: dialog))
    }
}

struct EditReminderIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.EditReminder.Title"
    static let description = IntentDescription("Intent.EditReminder.Description")

    @Parameter(title: "Intent.Parameter.Reminder")
    var reminder: ReminderEntity

    @Parameter(title: "Intent.Parameter.Time", kind: .time)
    var time: Date?

    @Parameter(title: "Intent.Parameter.Message")
    var message: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.EditReminder.Summary \(\.$reminder)") {
            \.$time
            \.$message
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ReminderEntity> & ProvidesDialog {
        let model = try IntentData.reminder(for: reminder)
        if let time {
            let components = Calendar.current.dateComponents([.hour, .minute], from: time)
            model.hour = components.hour ?? model.hour
            model.minute = components.minute ?? model.minute
        }
        if let message {
            model.message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        try await IntentData.commit()
        let updated = ReminderEntity(model)
        let timeText = updated.time.formatted(date: .omitted, time: .shortened)
        let name = updated.planName
        return .result(value: updated, dialog: IntentDialog(text: String(
            localized: "Intent.EditReminder.Dialog",
            defaultValue: "The reminder for \(name) is now at \(timeText)."
        )))
    }
}

struct DeleteReminderIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.DeleteReminder.Title"
    static let description = IntentDescription("Intent.DeleteReminder.Description")

    @Parameter(title: "Intent.Parameter.Reminder")
    var reminder: ReminderEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.DeleteReminder.Summary \(\.$reminder)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = try IntentData.reminder(for: reminder)
        let timeText = reminder.time.formatted(date: .omitted, time: .shortened)
        let name = model.template?.name ?? ""
        IntentData.context.delete(model)
        try await IntentData.commit()
        return .result(dialog: IntentDialog(text: String(
            localized: "Intent.DeleteReminder.Dialog",
            defaultValue: "Removed the \(timeText) reminder from \(name)."
        )))
    }
}

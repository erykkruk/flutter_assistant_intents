#if canImport(AppIntents)
import AppIntents
import Foundation

// MARK: - Intents
//
// These intents run inside the app process (openAppWhenRun = false). If the
// app is not running, the system launches it in the background; the bridge
// then waits for the Dart side to register handlers before answering. See
// AssistantIntentBridge for the cold-start behavior and README for the
// limitation notes.

/// Adds a task to the host app's list.
@available(iOS 16.0, *)
public struct AddTaskIntent: AppIntent {
    public static var title: LocalizedStringResource = "Add Task"
    public static var description = IntentDescription(
        "Adds a new task to your list."
    )
    public static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Title",
        requestValueDialog: "What should the task be called?"
    )
    public var taskTitle: String

    @Parameter(title: "Due date")
    public var dueDate: Date?

    @Parameter(title: "Notes")
    public var notes: String?

    public static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$taskTitle)") {
            \.$dueDate
            \.$notes
        }
    }

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let payload = try await AssistantIntentBridge.shared.performAddTask(
            title: taskTitle,
            dueDate: dueDate,
            notes: notes
        )
        let fallback = payload.success
            ? "Done. Task added."
            : "Sorry, the task could not be added."
        return .result(dialog: IntentDialog(stringLiteral: payload.message ?? fallback))
    }
}

/// Marks a task in the host app as completed, matched by its title.
@available(iOS 16.0, *)
public struct CompleteTaskIntent: AppIntent {
    public static var title: LocalizedStringResource = "Complete Task"
    public static var description = IntentDescription(
        "Marks a task from your list as done."
    )
    public static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Task",
        requestValueDialog: "Which task should be completed?"
    )
    public var taskTitle: String

    public static var parameterSummary: some ParameterSummary {
        Summary("Complete \(\.$taskTitle)")
    }

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let payload = try await AssistantIntentBridge.shared.performCompleteTask(
            title: taskTitle
        )
        let fallback = payload.success
            ? "Done. Task completed."
            : "Sorry, I could not find that task."
        return .result(dialog: IntentDialog(stringLiteral: payload.message ?? fallback))
    }
}

/// Filter for `QueryTasksIntent`; wire values match the Dart
/// `TaskQueryFilter` enum names.
@available(iOS 16.0, *)
public enum AssistantTaskFilter: String, AppEnum {
    case today
    case all

    public static var typeDisplayRepresentation: TypeDisplayRepresentation =
        "Task Filter"
    public static var caseDisplayRepresentations:
        [AssistantTaskFilter: DisplayRepresentation] = [
            .today: "Today",
            .all: "All",
        ]
}

/// Reads back the user's tasks (today or all).
@available(iOS 16.0, *)
public struct QueryTasksIntent: AppIntent {
    public static var title: LocalizedStringResource = "Show Tasks"
    public static var description = IntentDescription(
        "Tells you which tasks are on your list."
    )
    public static var openAppWhenRun: Bool = false

    private static let spokenTaskLimit = 5

    @Parameter(title: "Filter", default: .today)
    public var filter: AssistantTaskFilter

    public static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$filter) tasks")
    }

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let tasks = try await AssistantIntentBridge.shared.performQueryTasks(
            filter: filter.rawValue
        )
        return .result(dialog: IntentDialog(stringLiteral: Self.dialogText(
            for: tasks.filter { !$0.isCompleted },
            filter: filter
        )))
    }

    static func dialogText(
        for tasks: [AssistantTaskPayload],
        filter: AssistantTaskFilter
    ) -> String {
        let scope = filter == .today ? " for today" : ""
        guard !tasks.isEmpty else {
            return "You have no tasks\(scope)."
        }
        let titles = tasks.prefix(spokenTaskLimit).map(\.title)
        let suffix = tasks.count > spokenTaskLimit
            ? ", and \(tasks.count - spokenTaskLimit) more"
            : ""
        let plural = tasks.count == 1 ? "task" : "tasks"
        return "You have \(tasks.count) \(plural)\(scope): "
            + titles.joined(separator: ", ") + suffix + "."
    }
}

// MARK: - App Shortcuts

/// Zero-setup Siri phrases for the three intents. The `applicationName`
/// token resolves to the host app's display name, so the plugin never ships
/// a hardcoded product name.
@available(iOS 16.0, *)
public struct AssistantShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task in \(.applicationName)",
                "Add a task to \(.applicationName)",
                "Create a task in \(.applicationName)",
                "New task in \(.applicationName)",
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: CompleteTaskIntent(),
            phrases: [
                "Complete a task in \(.applicationName)",
                "Finish a task in \(.applicationName)",
                "Mark a task done in \(.applicationName)",
            ],
            shortTitle: "Complete Task",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: QueryTasksIntent(),
            phrases: [
                "What are my tasks in \(.applicationName)",
                "Show my \(.applicationName) tasks",
                "What's on my \(.applicationName) list today",
            ],
            shortTitle: "Show Tasks",
            systemImageName: "list.bullet.circle"
        )
    }
}

// MARK: - App Intents package

/// Lets host apps re-export the intents defined in this plugin.
///
/// App Intents metadata is extracted from the **app target** at build time.
/// Intents living in a library are only discovered when the host app
/// declares an `AppIntentsPackage` that includes this one (current SDKs
/// mark the protocol iOS 17.0+):
///
/// ```swift
/// // in Runner (AppDelegate.swift or a dedicated file)
/// import flutter_assistant_intents
///
/// @available(iOS 17.0, *)
/// struct RunnerAppIntentsPackage: AppIntentsPackage {
///     static var includedPackages: [any AppIntentsPackage.Type] {
///         [FlutterAssistantIntentsPackage.self]
///     }
/// }
/// ```
///
/// Hosts that must support iOS 16.x should instead declare thin wrapper
/// intents in the Runner target itself (see README).
@available(iOS 17.0, *)
public struct FlutterAssistantIntentsPackage: AppIntentsPackage {}
#endif

import 'models/add_task_request.dart';
import 'models/assistant_action_request.dart';
import 'models/assistant_task.dart';
import 'models/assistant_task_result.dart';
import 'models/complete_task_request.dart';
import 'models/query_tasks_request.dart';

/// Signature of the handler invoked when the assistant asks to add a task.
typedef AddTaskHandler = Future<AssistantTaskResult> Function(
  AddTaskRequest request,
);

/// Signature of the handler invoked when the assistant asks to complete a
/// task.
typedef CompleteTaskHandler = Future<AssistantTaskResult> Function(
  CompleteTaskRequest request,
);

/// Signature of the handler invoked when the assistant asks to list tasks.
typedef QueryTasksHandler = Future<List<AssistantTask>> Function(
  QueryTasksRequest request,
);

/// Signature of the handler invoked for app-defined custom actions.
typedef AssistantActionHandler = Future<AssistantTaskResult> Function(
  AssistantActionRequest request,
);

/// The set of app callbacks that fulfill assistant intents.
///
/// Register once, early in app startup, via
/// [AssistantIntents.registerHandlers]. Two layers are available and can be
/// mixed freely:
///
/// - **Task preset** ([onAddTask], [onCompleteTask], [onQueryTasks]) —
///   backs the plugin's built-in intents and shortcuts for task/todo apps.
/// - **Generic actions** ([onAction]) — backs custom `AppIntent`s declared
///   in the host's iOS Runner and [AndroidCustomShortcut]s, identified by an
///   app-defined action id. Use this to expose any domain, not just tasks.
///
/// ```dart
/// AssistantIntents.instance.registerHandlers(
///   AssistantIntentHandlers(
///     onAddTask: (request) async =>
///         const AssistantTaskResult.success(message: 'Task added'),
///     onAction: (request) async => switch (request.action) {
///       'order_coffee' => const AssistantTaskResult.success(
///           message: 'Your coffee is on its way.',
///         ),
///       _ => const AssistantTaskResult.failure('Unknown action.'),
///     },
///   ),
/// );
/// ```
///
/// Handlers should never throw — return a friendly
/// [AssistantTaskResult.failure] instead so the assistant has something to
/// speak. Thrown errors are converted into a generic failure by the plugin.
/// An intent arriving for a handler that was not registered is answered
/// with a polite "not available" message (or an empty list for queries).
class AssistantIntentHandlers {
  /// Creates the handler set. At least one callback must be provided.
  const AssistantIntentHandlers({
    this.onAddTask,
    this.onCompleteTask,
    this.onQueryTasks,
    this.onAction,
  }) : assert(
          onAddTask != null ||
              onCompleteTask != null ||
              onQueryTasks != null ||
              onAction != null,
          'Register at least one handler.',
        );

  /// Called when the user asks the assistant to add a task.
  final AddTaskHandler? onAddTask;

  /// Called when the user asks the assistant to complete a task.
  final CompleteTaskHandler? onCompleteTask;

  /// Called when the user asks the assistant what tasks they have.
  final QueryTasksHandler? onQueryTasks;

  /// Called for app-defined custom actions (custom iOS intents and Android
  /// custom shortcuts), identified by [AssistantActionRequest.action].
  final AssistantActionHandler? onAction;
}

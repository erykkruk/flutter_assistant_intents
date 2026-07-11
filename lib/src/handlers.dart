import 'models/add_task_request.dart';
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

/// The set of app callbacks that fulfill assistant intents.
///
/// Register once, early in app startup, via
/// [AssistantIntents.registerHandlers]:
///
/// ```dart
/// AssistantIntents.instance.registerHandlers(
///   AssistantIntentHandlers(
///     onAddTask: (request) async =>
///         const AssistantTaskResult.success(message: 'Task added'),
///     onCompleteTask: (request) async =>
///         const AssistantTaskResult.failure('Task not found'),
///     onQueryTasks: (request) async => <AssistantTask>[],
///   ),
/// );
/// ```
///
/// Handlers should never throw — return a friendly
/// [AssistantTaskResult.failure] instead so the assistant has something to
/// speak. Thrown errors are converted into a generic failure by the plugin.
class AssistantIntentHandlers {
  /// Creates the handler set. All three callbacks are required so the
  /// assistant never hits an unimplemented action.
  const AssistantIntentHandlers({
    required this.onAddTask,
    required this.onCompleteTask,
    required this.onQueryTasks,
  });

  /// Called when the user asks the assistant to add a task.
  final AddTaskHandler onAddTask;

  /// Called when the user asks the assistant to complete a task.
  final CompleteTaskHandler onCompleteTask;

  /// Called when the user asks the assistant what tasks they have.
  final QueryTasksHandler onQueryTasks;
}

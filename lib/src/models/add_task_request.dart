import '../exceptions.dart';

/// A request from the platform assistant to create a new task.
///
/// Produced when the user says e.g. "Add buy milk to `<app name>`" (iOS App
/// Intents) or taps the "Add task" app shortcut (Android).
class AddTaskRequest {
  /// Creates a request with the spoken/typed [title] and optional details.
  const AddTaskRequest({
    required this.title,
    this.dueDate,
    this.notes,
    this.choice,
  });

  /// Decodes a request from the raw method-channel payload.
  ///
  /// Throws [InvalidIntentPayloadException] when [map] is not a map.
  factory AddTaskRequest.fromMap(Object? map) {
    if (map is! Map) {
      throw const InvalidIntentPayloadException(
        'addTask payload must be a map',
      );
    }
    final dueDateRaw = map['dueDate'] as String?;
    return AddTaskRequest(
      title: (map['title'] as String?) ?? '',
      dueDate: dueDateRaw == null ? null : DateTime.tryParse(dueDateRaw),
      notes: map['notes'] as String?,
      choice: map['choice'] as String?,
    );
  }

  /// Title of the task to create.
  ///
  /// May be empty on Android: app shortcuts cannot carry free-form text, so
  /// an "Add task" shortcut launch delivers an empty title — treat it as
  /// "open the add-task flow".
  final String title;

  /// Optional due date the user provided.
  final DateTime? dueDate;

  /// Option the user picked in a confirmation prompt, or null on the first
  /// call.
  ///
  /// Set only when a previous run of this handler returned
  /// [AssistantTaskResult.needsConfirmation]; the value is the `id` of the
  /// chosen [AssistantChoice].
  final String? choice;

  /// Optional free-form notes.
  final String? notes;
}

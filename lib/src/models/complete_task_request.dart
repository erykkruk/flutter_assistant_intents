import '../exceptions.dart';

/// A request from the platform assistant to mark a task as done.
///
/// The assistant provides only the spoken [title]; host apps are expected to
/// resolve it against their open tasks (exact or fuzzy matching).
class CompleteTaskRequest {
  /// Creates a request for the task matching [title].
  const CompleteTaskRequest({required this.title, this.choice});

  /// Decodes a request from the raw method-channel payload.
  ///
  /// Throws [InvalidIntentPayloadException] when [map] is not a map.
  factory CompleteTaskRequest.fromMap(Object? map) {
    if (map is! Map) {
      throw const InvalidIntentPayloadException(
        'completeTask payload must be a map',
      );
    }
    return CompleteTaskRequest(
      title: (map['title'] as String?) ?? '',
      choice: map['choice'] as String?,
    );
  }

  /// Option the user picked in a confirmation prompt, or null on the first
  /// call.
  ///
  /// Set only when a previous run of this handler returned
  /// [AssistantTaskResult.needsConfirmation]; the value is the `id` of the
  /// chosen [AssistantChoice].
  final String? choice;

  /// Title of the task to complete, as spoken/typed by the user.
  final String title;
}

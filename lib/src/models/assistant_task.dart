/// A single task returned to the assistant from [onQueryTasks].
///
/// The assistant reads [title] (and optionally [dueDate]) back to the user.
class AssistantTask {
  /// Creates a task snapshot for the assistant.
  const AssistantTask({
    required this.id,
    required this.title,
    this.dueDate,
    this.isCompleted = false,
  });

  /// Stable identifier of the task inside the host app.
  final String id;

  /// Title the assistant can display or speak.
  final String title;

  /// Due date, when the task has one.
  final DateTime? dueDate;

  /// Whether the task is already completed.
  final bool isCompleted;

  /// Encodes the task for the method-channel response to the native side.
  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'title': title,
        'dueDate': dueDate?.toIso8601String(),
        'isCompleted': isCompleted,
      };
}

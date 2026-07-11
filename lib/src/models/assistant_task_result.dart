/// Outcome of an add/complete task handler, spoken back by the assistant.
class AssistantTaskResult {
  /// Creates a result. Prefer [AssistantTaskResult.success] /
  /// [AssistantTaskResult.failure] for readability.
  const AssistantTaskResult({
    required this.success,
    this.message,
    this.taskId,
  });

  /// A successful outcome with an optional confirmation [message]
  /// (e.g. "Added 'Buy milk' to your list") and the created/affected
  /// [taskId].
  const AssistantTaskResult.success({String? message, String? taskId})
      : this(success: true, message: message, taskId: taskId);

  /// A failed outcome with a friendly, speakable [message]
  /// (e.g. "Please open the app and sign in first").
  const AssistantTaskResult.failure(String message)
      : this(success: false, message: message);

  /// Whether the handler fulfilled the request.
  final bool success;

  /// Friendly sentence the assistant can speak or display. Keep it short,
  /// user-facing and free of technical detail.
  final String? message;

  /// Identifier of the task that was created or completed, when applicable.
  final String? taskId;

  /// Encodes the result for the method-channel response to the native side.
  Map<String, Object?> toMap() => <String, Object?>{
        'success': success,
        'message': message,
        'taskId': taskId,
      };
}

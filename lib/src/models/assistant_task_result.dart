import 'assistant_choice.dart';

/// Outcome of an add/complete task handler, spoken back by the assistant.
class AssistantTaskResult {
  /// Creates a result. Prefer [AssistantTaskResult.success] /
  /// [AssistantTaskResult.failure] for readability.
  const AssistantTaskResult({
    required this.success,
    this.message,
    this.taskId,
    this.confirmationDialog,
    this.confirmationOptions,
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

  /// Asks the assistant to confirm before the handler commits.
  ///
  /// The assistant speaks [dialog], offers [options], and then calls the
  /// same handler again with the chosen option's id in `request.choice`.
  /// Nothing is performed in between: deciding what a choice means is the
  /// handler's job.
  ///
  /// ```dart
  /// onAction: (request) async {
  ///   if (request.action != 'clear_completed') { ... }
  ///   if (request.choice == null) {
  ///     return const AssistantTaskResult.needsConfirmation(
  ///       dialog: 'Delete all completed tasks?',
  ///       options: [
  ///         AssistantChoice(
  ///           id: 'delete',
  ///           title: 'Delete them',
  ///           style: AssistantChoiceStyle.destructive,
  ///         ),
  ///         AssistantChoice.cancel,
  ///       ],
  ///     );
  ///   }
  ///   if (request.choice == 'cancel') {
  ///     return const AssistantTaskResult.success(message: 'Nothing deleted.');
  ///   }
  ///   return const AssistantTaskResult.success(message: 'All clear.');
  /// }
  /// ```
  ///
  /// Confirmation prompts need **iOS 26 or newer**. On older systems, and on
  /// Android shortcuts, the prompt cannot be shown: the assistant speaks
  /// [fallbackMessage] instead and the handler is *not* called again, so the
  /// action stays unperformed. That default is the safe one for the
  /// destructive operations this is meant for; pass your own wording to
  /// override it.
  ///
  /// An empty [options] list requests no prompt at all: the result degrades
  /// to a plain failure carrying [fallbackMessage], because an assistant
  /// cannot ask a question with nothing to pick.
  const AssistantTaskResult.needsConfirmation({
    required String dialog,
    required List<AssistantChoice> options,
    String? fallbackMessage,
  })  : success = false,
        taskId = null,
        message = fallbackMessage,
        confirmationDialog = dialog,
        confirmationOptions = options;

  /// Whether the handler fulfilled the request.
  final bool success;

  /// Friendly sentence the assistant can speak or display. Keep it short,
  /// user-facing and free of technical detail.
  final String? message;

  /// Identifier of the task that was created or completed, when applicable.
  final String? taskId;

  /// Question the assistant asks before the handler commits, when this
  /// result came from [AssistantTaskResult.needsConfirmation].
  final String? confirmationDialog;

  /// Options offered alongside [confirmationDialog].
  final List<AssistantChoice>? confirmationOptions;

  /// Whether this result asks the assistant for a confirmation instead of
  /// reporting an outcome.
  bool get needsChoice =>
      confirmationDialog != null && (confirmationOptions?.isNotEmpty ?? false);

  /// Encodes the result for the method-channel response to the native side.
  Map<String, Object?> toMap() => <String, Object?>{
        'success': success,
        'message': message ?? (needsChoice ? _defaultFallback : null),
        'taskId': taskId,
        if (needsChoice)
          'confirmation': <String, Object?>{
            'dialog': confirmationDialog,
            'options': confirmationOptions!
                .map((option) => option.toMap())
                .toList(growable: false),
          },
      };

  /// Spoken when a confirmation prompt cannot be shown and the handler set
  /// no wording of its own.
  static const String _defaultFallback = 'Please open the app to confirm this.';
}

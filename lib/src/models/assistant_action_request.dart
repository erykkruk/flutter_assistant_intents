import '../exceptions.dart';

/// A request for a custom, app-defined action.
///
/// Produced by the generic action layer: custom `AppIntent`s declared in the
/// host's Runner target (iOS) and custom app shortcuts (Android) both arrive
/// here, identified by [action]. Use this when the built-in task intents do
/// not fit your app's domain.
class AssistantActionRequest {
  /// Creates a request for [action] with optional [parameters].
  const AssistantActionRequest({
    required this.action,
    this.parameters = const <String, Object?>{},
  });

  /// Decodes a request from the raw method-channel payload.
  ///
  /// Throws [InvalidIntentPayloadException] when [map] is not a map or the
  /// action id is missing.
  factory AssistantActionRequest.fromMap(Object? map) {
    if (map is! Map) {
      throw const InvalidIntentPayloadException(
        'performAction payload must be a map',
      );
    }
    final action = map['action'] as String?;
    if (action == null || action.isEmpty) {
      throw const InvalidIntentPayloadException(
        'performAction payload is missing the action id',
      );
    }
    final rawParameters = map['parameters'];
    return AssistantActionRequest(
      action: action,
      parameters: rawParameters is Map
          ? rawParameters.map((k, v) => MapEntry('$k', v))
          : const <String, Object?>{},
    );
  }

  /// App-defined identifier of the action (e.g. `'order_coffee'`).
  final String action;

  /// Free-form parameters supplied by the platform intent or shortcut.
  final Map<String, Object?> parameters;
}

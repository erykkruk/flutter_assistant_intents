/// Base class for all errors thrown by `flutter_assistant_intents`.
abstract class AssistantIntentsException implements Exception {
  /// Creates an exception with a human-readable [message].
  const AssistantIntentsException(this.message);

  /// Human-readable description of what went wrong.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when a native shortcut operation fails on the platform side.
class PlatformShortcutException extends AssistantIntentsException {
  /// Creates the exception with a [message] and optional platform [code].
  const PlatformShortcutException(super.message, {this.code});

  /// Platform-specific error code, when the native side provided one.
  final String? code;
}

/// Thrown when the native side delivers a payload the Dart layer cannot
/// decode (e.g. a missing required field).
class InvalidIntentPayloadException extends AssistantIntentsException {
  /// Creates the exception with a [message] describing the malformed field.
  const InvalidIntentPayloadException(super.message);
}

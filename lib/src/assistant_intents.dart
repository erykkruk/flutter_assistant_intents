import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'exceptions.dart';
import 'handlers.dart';
import 'models/add_task_request.dart';
import 'models/android_shortcuts_config.dart';
import 'models/assistant_action_request.dart';
import 'models/assistant_task.dart';
import 'models/assistant_task_result.dart';
import 'models/complete_task_request.dart';
import 'models/query_tasks_request.dart';

/// Entry point for exposing task actions to the platform voice assistant.
///
/// Typical usage, early in app startup (after your dependency graph is
/// ready, before `runApp` completes its first frame is ideal):
///
/// ```dart
/// AssistantIntents.instance.registerHandlers(
///   AssistantIntentHandlers(
///     onAddTask: myAddTask,
///     onCompleteTask: myCompleteTask,
///     onQueryTasks: myQueryTasks,
///   ),
/// );
/// await AssistantIntents.instance.updateShortcuts();
/// ```
///
/// The native side queues assistant requests that arrive before
/// [registerHandlers] is called (cold start) for a short grace period, then
/// answers the assistant with a friendly "open the app first" message.
class AssistantIntents {
  AssistantIntents._();

  /// The shared instance.
  static final AssistantIntents instance = AssistantIntents._();

  /// Name of the method channel shared with the native implementations.
  static const String channelName = 'tech.ravenlab/flutter_assistant_intents';

  static const MethodChannel _channel = MethodChannel(channelName);

  static const String _methodAddTask = 'intent.addTask';
  static const String _methodCompleteTask = 'intent.completeTask';
  static const String _methodQueryTasks = 'intent.queryTasks';
  static const String _methodPerformAction = 'intent.performAction';
  static const String _methodHandlersRegistered = 'handlers.registered';
  static const String _methodUpdateShortcuts = 'shortcuts.update';

  static const String _genericFailureMessage =
      'Something went wrong. Please try again in the app.';
  static const String _unsupportedActionMessage =
      "This action isn't available in this app.";

  AssistantIntentHandlers? _handlers;

  /// Whether [registerHandlers] has been called.
  bool get hasHandlers => _handlers != null;

  /// Registers the app callbacks that fulfill assistant intents and tells
  /// the native side it may start (or resume) delivering requests.
  ///
  /// Safe to call again to replace the handlers (e.g. after re-login).
  void registerHandlers(AssistantIntentHandlers handlers) {
    _handlers = handlers;
    _channel.setMethodCallHandler(_handleNativeCall);
    // Fire-and-forget: on platforms without a native implementation (tests,
    // desktop, web) this must never crash app startup.
    unawaited(_invokeNativeSafely(_methodHandlersRegistered));
  }

  /// Refreshes the platform shortcut donations.
  ///
  /// - **Android:** publishes/updates the dynamic app shortcuts using the
  ///   labels from [androidShortcuts] (pass localized strings).
  /// - **iOS:** re-evaluates App Shortcut parameters so Siri phrase
  ///   suggestions stay current.
  ///
  /// No-op-safe: resolves normally when the platform has no implementation,
  /// so it can be called unconditionally on every startup.
  Future<void> updateShortcuts({
    AndroidShortcutsConfig androidShortcuts = const AndroidShortcutsConfig(),
  }) =>
      _invokeNativeSafely(_methodUpdateShortcuts, androidShortcuts.toMap());

  Future<Object?> _handleNativeCall(MethodCall call) async {
    final handlers = _handlers;
    if (handlers == null) {
      // registerHandlers sets the method-call handler, so this only happens
      // if handlers were somehow cleared; answer with a safe failure.
      return const AssistantTaskResult.failure(_genericFailureMessage).toMap();
    }
    switch (call.method) {
      case _methodAddTask:
        final onAddTask = handlers.onAddTask;
        if (onAddTask == null) return _unsupportedActionResult();
        return _guardResult(
          () => onAddTask(AddTaskRequest.fromMap(call.arguments)),
        );
      case _methodCompleteTask:
        final onCompleteTask = handlers.onCompleteTask;
        if (onCompleteTask == null) return _unsupportedActionResult();
        return _guardResult(
          () => onCompleteTask(CompleteTaskRequest.fromMap(call.arguments)),
        );
      case _methodQueryTasks:
        final onQueryTasks = handlers.onQueryTasks;
        if (onQueryTasks == null) return const <Map<String, Object?>>[];
        return _guardQuery(
          () => onQueryTasks(QueryTasksRequest.fromMap(call.arguments)),
        );
      case _methodPerformAction:
        final onAction = handlers.onAction;
        if (onAction == null) return _unsupportedActionResult();
        return _guardResult(
          () => onAction(AssistantActionRequest.fromMap(call.arguments)),
        );
      default:
        throw MissingPluginException('Unknown method ${call.method}');
    }
  }

  Map<String, Object?> _unsupportedActionResult() =>
      const AssistantTaskResult.failure(_unsupportedActionMessage).toMap();

  /// Runs an add/complete handler and converts any thrown error into a
  /// generic speakable failure — the assistant must always get an answer.
  Future<Map<String, Object?>> _guardResult(
    Future<AssistantTaskResult> Function() body,
  ) async {
    try {
      return (await body()).toMap();
    } catch (error, stackTrace) {
      _reportHandlerError(error, stackTrace);
      return const AssistantTaskResult.failure(_genericFailureMessage).toMap();
    }
  }

  /// Runs the query handler; a thrown error yields an empty list so the
  /// assistant reports "no tasks" instead of failing.
  Future<List<Map<String, Object?>>> _guardQuery(
    Future<List<AssistantTask>> Function() body,
  ) async {
    try {
      final tasks = await body();
      return tasks.map((t) => t.toMap()).toList();
    } catch (error, stackTrace) {
      _reportHandlerError(error, stackTrace);
      return const <Map<String, Object?>>[];
    }
  }

  Future<void> _invokeNativeSafely(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // No native implementation (tests, web, desktop) — by design a no-op.
    } on PlatformException catch (e) {
      throw PlatformShortcutException(
        e.message ?? 'Native call $method failed',
        code: e.code,
      );
    }
  }

  void _reportHandlerError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'flutter_assistant_intents',
        context: ErrorDescription('while handling an assistant intent'),
      ),
    );
  }
}

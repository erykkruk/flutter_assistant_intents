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
import 'models/task_query_filter.dart';

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
  static const String _methodHandlersSync = 'handlers.sync';
  static const String _methodUpdateShortcuts = 'shortcuts.update';
  static const String _methodReportShortcutUsed = 'shortcuts.reportUsed';
  static const String _methodDonateAddTask = 'donations.addTask';
  static const String _methodDonateCompleteTask = 'donations.completeTask';
  static const String _methodDonateQueryTasks = 'donations.queryTasks';

  static const String _reservedShortcutIdPrefix = 'flutter_assistant_intents.';

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
  /// On Android, plugin shortcuts that are no longer part of
  /// [androidShortcuts] (a removed custom shortcut, or the task preset after
  /// `publishTaskShortcuts: false`) are removed. Shortcuts the host app
  /// publishes itself are never touched.
  ///
  /// In debug builds, asserts that every custom shortcut has a non-blank,
  /// unique `id` and a non-blank `action`, and that no id uses the plugin's
  /// reserved `flutter_assistant_intents.` prefix. Such entries would
  /// otherwise be skipped or overwritten silently on the native side.
  ///
  /// No-op-safe: resolves normally when the platform has no implementation,
  /// so it can be called unconditionally on every startup.
  Future<void> updateShortcuts({
    AndroidShortcutsConfig androidShortcuts = const AndroidShortcutsConfig(),
  }) async {
    assert(_debugCheckCustomShortcuts(androidShortcuts.customShortcuts));
    await _invokeNativeSafely(_methodUpdateShortcuts, androidShortcuts.toMap());
  }

  /// Tells the system the user just added a task **in the app's own UI**, so
  /// it can suggest the action later.
  ///
  /// - **iOS:** donates the built-in Add Task intent with these values via
  ///   `IntentDonationManager`; Siri Suggestions, Spotlight and the Lock
  ///   Screen learn from it.
  /// - **Android:** reports the "Add task" app shortcut as used, which feeds
  ///   launcher ranking and shortcut predictions.
  ///
  /// Call it after the action succeeded, not from an assistant handler:
  /// runs started by the assistant are recorded by the system already.
  /// No-op-safe on platforms without an implementation.
  ///
  /// Throws [ArgumentError] when [title] is blank, and
  /// [PlatformShortcutException] when the native donation fails.
  Future<void> donateAddTask({
    required String title,
    DateTime? dueDate,
    String? notes,
  }) async {
    _checkNotBlank(title, 'title');
    await _invokeNativeSafely(_methodDonateAddTask, <String, Object?>{
      'dueDate': dueDate?.toUtc().toIso8601String(),
      'notes': notes,
      'title': title,
    });
  }

  /// Tells the system the user just completed a task in the app's own UI.
  ///
  /// iOS donates the built-in Complete Task intent. Android has no matching
  /// launcher shortcut, so this resolves without doing anything there.
  /// See [donateAddTask] for when to call it.
  ///
  /// Throws [ArgumentError] when [title] is blank, and
  /// [PlatformShortcutException] when the native donation fails.
  Future<void> donateCompleteTask({required String title}) async {
    _checkNotBlank(title, 'title');
    await _invokeNativeSafely(
      _methodDonateCompleteTask,
      <String, Object?>{'title': title},
    );
  }

  /// Tells the system the user just looked at their tasks in the app.
  ///
  /// iOS donates the built-in Show Tasks intent with [filter]. Android
  /// reports the "Today" app shortcut as used when [filter] is
  /// [TaskQueryFilter.today]. See [donateAddTask] for when to call it.
  ///
  /// Throws [PlatformShortcutException] when the native donation fails.
  Future<void> donateQueryTasks({
    TaskQueryFilter filter = TaskQueryFilter.today,
  }) =>
      _invokeNativeSafely(
        _methodDonateQueryTasks,
        <String, Object?>{'filter': filter.name},
      );

  /// Reports that the user did, inside the app, what the Android shortcut
  /// [shortcutId] does (an [AndroidCustomShortcut.id], usually).
  ///
  /// Android uses this for launcher ranking and shortcut predictions. iOS
  /// has no equivalent for host-declared intents (donate those from Swift
  /// with `IntentDonationManager`), so this resolves without doing anything
  /// there.
  ///
  /// Throws [ArgumentError] when [shortcutId] is blank, and
  /// [PlatformShortcutException] when the native call fails.
  Future<void> reportAndroidShortcutUsed(String shortcutId) async {
    _checkNotBlank(shortcutId, 'shortcutId');
    await _invokeNativeSafely(
      _methodReportShortcutUsed,
      <String, Object?>{'id': shortcutId},
    );
  }

  void _checkNotBlank(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'must not be blank');
    }
  }

  bool _debugCheckCustomShortcuts(List<AndroidCustomShortcut> shortcuts) {
    final seenIds = <String>{};
    for (final shortcut in shortcuts) {
      if (shortcut.id.trim().isEmpty) {
        throw FlutterError(
          'AndroidCustomShortcut for action "${shortcut.action}" has a blank '
          'id. Android would skip it.',
        );
      }
      if (shortcut.action.trim().isEmpty) {
        throw FlutterError(
          'AndroidCustomShortcut "${shortcut.id}" has a blank action. '
          'Android would skip it.',
        );
      }
      if (shortcut.id.startsWith(_reservedShortcutIdPrefix)) {
        throw FlutterError(
          'AndroidCustomShortcut id "${shortcut.id}" uses the reserved '
          '"$_reservedShortcutIdPrefix" prefix of the built-in shortcuts.',
        );
      }
      if (!seenIds.add(shortcut.id)) {
        throw FlutterError(
          'AndroidCustomShortcut id "${shortcut.id}" is used more than once. '
          'Android would keep only the last one.',
        );
      }
    }
    return true;
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    final handlers = _handlers;
    if (handlers == null) {
      // registerHandlers sets the method-call handler, so this only happens
      // if handlers were somehow cleared; answer with a safe failure.
      return const AssistantTaskResult.failure(_genericFailureMessage).toMap();
    }
    switch (call.method) {
      // Native asks whether handlers are already registered — covers the
      // boot race on iOS headless cold start, where 'handlers.registered'
      // can fire before the plugin attaches to the new engine's channel.
      case _methodHandlersSync:
        return true;
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

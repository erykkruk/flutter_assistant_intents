/// Configuration of the dynamic app shortcuts published on Android.
///
/// Pass localized strings from your app so the launcher never shows
/// placeholder text. iOS ignores this configuration — App Shortcut phrases
/// are declared statically in the App Intents metadata.
class AndroidShortcutsConfig {
  /// Creates the shortcut configuration.
  const AndroidShortcutsConfig({
    this.publishTaskShortcuts = true,
    this.addTaskLabel = 'Add task',
    this.addTaskLongLabel = 'Add a new task',
    this.queryTodayLabel = 'Today',
    this.queryTodayLongLabel = "Show today's tasks",
    this.customShortcuts = const <AndroidCustomShortcut>[],
  });

  /// Whether to publish the built-in task shortcuts ("Add task", "Today").
  ///
  /// Set to `false` for apps that only use the generic action layer
  /// ([customShortcuts] + `onAction`).
  final bool publishTaskShortcuts;

  /// Short label of the "add task" shortcut (launcher long-press menu).
  /// Keep it under ~10 characters — launchers truncate longer labels.
  final String addTaskLabel;

  /// Long label of the "add task" shortcut, shown when space allows.
  final String addTaskLongLabel;

  /// Short label of the "today's tasks" shortcut.
  /// Keep it under ~10 characters — launchers truncate longer labels.
  final String queryTodayLabel;

  /// Long label of the "today's tasks" shortcut.
  final String queryTodayLongLabel;

  /// App-defined shortcuts routed to the `onAction` handler.
  final List<AndroidCustomShortcut> customShortcuts;

  /// Encodes the configuration for the method channel.
  Map<String, Object?> toMap() => <String, Object?>{
        'addTaskLabel': addTaskLabel,
        'addTaskLongLabel': addTaskLongLabel,
        'customShortcuts':
            customShortcuts.map((shortcut) => shortcut.toMap()).toList(),
        'publishTaskShortcuts': publishTaskShortcuts,
        'queryTodayLabel': queryTodayLabel,
        'queryTodayLongLabel': queryTodayLongLabel,
      };
}

/// An app-defined dynamic shortcut published on Android.
///
/// Tapping it launches (or resumes) the app and invokes the registered
/// `onAction` handler with [action] (and no parameters — launcher shortcuts
/// cannot carry runtime input).
class AndroidCustomShortcut {
  /// Creates a custom shortcut definition.
  const AndroidCustomShortcut({
    required this.id,
    required this.action,
    required this.shortLabel,
    String? longLabel,
  }) : longLabel = longLabel ?? shortLabel;

  /// Stable, unique shortcut id (used by the launcher to de-duplicate).
  final String id;

  /// Action id delivered to the `onAction` handler when tapped.
  final String action;

  /// Short label shown in the launcher long-press menu.
  /// Keep it under ~10 characters — launchers truncate longer labels.
  final String shortLabel;

  /// Long label shown when space allows. Defaults to [shortLabel].
  final String longLabel;

  /// Encodes the shortcut for the method channel.
  Map<String, Object?> toMap() => <String, Object?>{
        'action': action,
        'id': id,
        'longLabel': longLabel,
        'shortLabel': shortLabel,
      };
}

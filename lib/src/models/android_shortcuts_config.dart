/// Labels for the dynamic app shortcuts published on Android.
///
/// Pass localized strings from your app so the launcher never shows
/// placeholder text. iOS ignores this configuration — App Shortcut phrases
/// are declared statically in the App Intents metadata.
class AndroidShortcutsConfig {
  /// Creates the shortcut label configuration.
  const AndroidShortcutsConfig({
    this.addTaskLabel = 'Add task',
    this.addTaskLongLabel = 'Add a new task',
    this.queryTodayLabel = "Today's tasks",
    this.queryTodayLongLabel = "Show today's tasks",
  });

  /// Short label of the "add task" shortcut (launcher long-press menu).
  final String addTaskLabel;

  /// Long label of the "add task" shortcut, shown when space allows.
  final String addTaskLongLabel;

  /// Short label of the "today's tasks" shortcut.
  final String queryTodayLabel;

  /// Long label of the "today's tasks" shortcut.
  final String queryTodayLongLabel;

  /// Encodes the labels for the method channel.
  Map<String, Object?> toMap() => <String, Object?>{
        'addTaskLabel': addTaskLabel,
        'addTaskLongLabel': addTaskLongLabel,
        'queryTodayLabel': queryTodayLabel,
        'queryTodayLongLabel': queryTodayLongLabel,
      };
}

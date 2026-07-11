/// Which subset of tasks a [QueryTasksRequest] asks for.
///
/// The wire value is the enum [name] (`'today'` / `'all'`), shared with the
/// native implementations.
enum TaskQueryFilter {
  /// Tasks due today (host apps decide the exact "today" semantics,
  /// e.g. local midnight-to-midnight).
  today,

  /// All open tasks.
  all;

  /// Parses a wire [value] coming from the native side.
  ///
  /// Falls back to [TaskQueryFilter.today] for unknown values so that a newer
  /// native layer never crashes an older Dart layer.
  static TaskQueryFilter fromWire(String? value) => TaskQueryFilter.values
      .firstWhere((f) => f.name == value, orElse: () => TaskQueryFilter.today);
}

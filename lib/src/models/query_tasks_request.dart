import '../exceptions.dart';
import 'task_query_filter.dart';

/// A request from the platform assistant to list tasks.
class QueryTasksRequest {
  /// Creates a request for tasks matching [filter].
  const QueryTasksRequest({required this.filter});

  /// Decodes a request from the raw method-channel payload.
  ///
  /// Throws [InvalidIntentPayloadException] when [map] is not a map.
  factory QueryTasksRequest.fromMap(Object? map) {
    if (map is! Map) {
      throw const InvalidIntentPayloadException(
        'queryTasks payload must be a map',
      );
    }
    return QueryTasksRequest(
      filter: TaskQueryFilter.fromWire(map['filter'] as String?),
    );
  }

  /// Which subset of tasks the assistant asked for.
  final TaskQueryFilter filter;
}

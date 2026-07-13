import 'package:flutter_assistant_intents/flutter_assistant_intents.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AddTaskRequest', () {
    test('parses a full payload', () {
      final request = AddTaskRequest.fromMap({
        'title': 'Buy milk',
        'dueDate': '2026-07-11T08:30:00.000Z',
        'notes': 'oat',
      });

      expect(request.title, 'Buy milk');
      expect(request.dueDate, DateTime.utc(2026, 7, 11, 8, 30));
      expect(request.notes, 'oat');
    });

    test('tolerates an unparsable due date', () {
      final request = AddTaskRequest.fromMap({
        'title': 'X',
        'dueDate': 'not-a-date',
      });

      expect(request.dueDate, isNull);
    });

    test('rejects a non-map payload', () {
      expect(
        () => AddTaskRequest.fromMap('nope'),
        throwsA(isA<InvalidIntentPayloadException>()),
      );
    });
  });

  group('CompleteTaskRequest', () {
    test('parses the title', () {
      expect(CompleteTaskRequest.fromMap({'title': 'Dishes'}).title, 'Dishes');
    });

    test('rejects a non-map payload', () {
      expect(
        () => CompleteTaskRequest.fromMap(42),
        throwsA(isA<InvalidIntentPayloadException>()),
      );
    });
  });

  group('QueryTasksRequest', () {
    test('parses known filters', () {
      expect(
        QueryTasksRequest.fromMap({'filter': 'all'}).filter,
        TaskQueryFilter.all,
      );
      expect(
        QueryTasksRequest.fromMap({'filter': 'today'}).filter,
        TaskQueryFilter.today,
      );
    });

    test('falls back to today for unknown or missing filters', () {
      expect(
        QueryTasksRequest.fromMap(<String, Object?>{}).filter,
        TaskQueryFilter.today,
      );
    });
  });

  group('AssistantActionRequest', () {
    test('parses the action id and parameters', () {
      final request = AssistantActionRequest.fromMap({
        'action': 'order_coffee',
        'parameters': {'size': 'large'},
      });

      expect(request.action, 'order_coffee');
      expect(request.parameters, {'size': 'large'});
    });

    test('missing parameters decode as an empty map', () {
      final request = AssistantActionRequest.fromMap({'action': 'refresh'});

      expect(request.parameters, isEmpty);
    });

    test('rejects a missing or empty action id', () {
      expect(
        () => AssistantActionRequest.fromMap(<String, Object?>{}),
        throwsA(isA<InvalidIntentPayloadException>()),
      );
      expect(
        () => AssistantActionRequest.fromMap({'action': ''}),
        throwsA(isA<InvalidIntentPayloadException>()),
      );
    });

    test('rejects a non-map payload', () {
      expect(
        () => AssistantActionRequest.fromMap('nope'),
        throwsA(isA<InvalidIntentPayloadException>()),
      );
    });
  });

  group('AndroidShortcutsConfig', () {
    test('encodes defaults to the wire format', () {
      const config = AndroidShortcutsConfig();

      expect(config.toMap(), {
        'addTaskLabel': 'Add task',
        'addTaskLongLabel': 'Add a new task',
        'customShortcuts': <Object?>[],
        'publishTaskShortcuts': true,
        'queryTodayLabel': 'Today',
        'queryTodayLongLabel': "Show today's tasks",
      });
    });

    test('custom shortcut longLabel falls back to shortLabel', () {
      const shortcut = AndroidCustomShortcut(
        id: 'x',
        action: 'do_x',
        shortLabel: 'X',
      );

      expect(shortcut.longLabel, 'X');
      expect(shortcut.toMap(), {
        'action': 'do_x',
        'id': 'x',
        'longLabel': 'X',
        'shortLabel': 'X',
      });
    });
  });

  group('AssistantIntentHandlers', () {
    test('asserts when no handler is provided', () {
      expect(
        () => AssistantIntentHandlers(),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('AssistantTask', () {
    test('encodes to the wire format', () {
      final task = AssistantTask(
        id: 'id-1',
        title: 'Water plants',
        dueDate: DateTime.utc(2026, 7, 11),
      );

      expect(task.toMap(), {
        'id': 'id-1',
        'title': 'Water plants',
        'dueDate': '2026-07-11T00:00:00.000Z',
        'isCompleted': false,
      });
    });
  });

  group('AssistantTaskResult', () {
    test('success factory encodes success', () {
      const result = AssistantTaskResult.success(message: 'Done', taskId: 't1');

      expect(result.toMap(), {
        'success': true,
        'message': 'Done',
        'taskId': 't1',
      });
    });

    test('failure factory encodes failure', () {
      const result = AssistantTaskResult.failure('No account');

      expect(result.toMap(), {
        'success': false,
        'message': 'No account',
        'taskId': null,
      });
    });
  });
}

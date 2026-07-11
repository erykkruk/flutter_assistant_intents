import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_assistant_intents/flutter_assistant_intents.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(AssistantIntents.channelName);
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final outgoingCalls = <MethodCall>[];

  setUp(() {
    outgoingCalls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      outgoingCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  /// Simulates the native side calling into the Dart handler and returns the
  /// decoded response envelope.
  Future<Object?> invokeFromNative(String method, Object? arguments) async {
    final data = codec.encodeMethodCall(MethodCall(method, arguments));
    ByteData? responseData;
    await messenger.handlePlatformMessage(
      AssistantIntents.channelName,
      data,
      (reply) => responseData = reply,
    );
    expect(responseData, isNotNull, reason: 'native call $method got no reply');
    return codec.decodeEnvelope(responseData!);
  }

  AssistantIntentHandlers handlers({
    AddTaskHandler? onAddTask,
    CompleteTaskHandler? onCompleteTask,
    QueryTasksHandler? onQueryTasks,
  }) {
    return AssistantIntentHandlers(
      onAddTask:
          onAddTask ?? (request) async => const AssistantTaskResult.success(),
      onCompleteTask: onCompleteTask ??
          (request) async => const AssistantTaskResult.success(),
      onQueryTasks: onQueryTasks ?? (request) async => const <AssistantTask>[],
    );
  }

  group('registerHandlers', () {
    test('notifies the native side that handlers are ready', () async {
      AssistantIntents.instance.registerHandlers(handlers());
      await null; // let the fire-and-forget invoke complete

      expect(AssistantIntents.instance.hasHandlers, isTrue);
      expect(
        outgoingCalls.map((c) => c.method),
        contains('handlers.registered'),
      );
    });
  });

  group('intent.addTask', () {
    test('decodes the payload and returns the handler result', () async {
      AddTaskRequest? received;
      AssistantIntents.instance.registerHandlers(
        handlers(
          onAddTask: (request) async {
            received = request;
            return const AssistantTaskResult.success(
              message: 'Added',
              taskId: 'task-1',
            );
          },
        ),
      );

      final response = await invokeFromNative('intent.addTask', {
        'title': 'Buy milk',
        'dueDate': '2026-07-11T10:00:00.000Z',
        'notes': 'semi-skimmed',
      });

      expect(received!.title, 'Buy milk');
      expect(received!.dueDate, DateTime.utc(2026, 7, 11, 10));
      expect(received!.notes, 'semi-skimmed');
      expect(response, {
        'success': true,
        'message': 'Added',
        'taskId': 'task-1',
      });
    });

    test('missing optional fields decode as null / empty', () async {
      AddTaskRequest? received;
      AssistantIntents.instance.registerHandlers(
        handlers(
          onAddTask: (request) async {
            received = request;
            return const AssistantTaskResult.success();
          },
        ),
      );

      await invokeFromNative('intent.addTask', {'title': ''});

      expect(received!.title, isEmpty);
      expect(received!.dueDate, isNull);
      expect(received!.notes, isNull);
    });

    test('a throwing handler yields a generic speakable failure', () async {
      AssistantIntents.instance.registerHandlers(
        handlers(onAddTask: (request) async => throw StateError('boom')),
      );

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {}; // swallow the reported error
      addTearDown(() => FlutterError.onError = originalOnError);

      final response = await invokeFromNative(
        'intent.addTask',
        {'title': 'X'},
      );

      expect(response, isA<Map<Object?, Object?>>());
      final map = response! as Map<Object?, Object?>;
      expect(map['success'], isFalse);
      expect(map['message'], isNotEmpty);
    });
  });

  group('intent.completeTask', () {
    test('decodes the title and returns the handler result', () async {
      CompleteTaskRequest? received;
      AssistantIntents.instance.registerHandlers(
        handlers(
          onCompleteTask: (request) async {
            received = request;
            return const AssistantTaskResult.failure('Task not found');
          },
        ),
      );

      final response =
          await invokeFromNative('intent.completeTask', {'title': 'Laundry'});

      expect(received!.title, 'Laundry');
      final map = response! as Map<Object?, Object?>;
      expect(map['success'], isFalse);
      expect(map['message'], 'Task not found');
    });
  });

  group('intent.queryTasks', () {
    test('decodes the filter and encodes the task list', () async {
      QueryTasksRequest? received;
      AssistantIntents.instance.registerHandlers(
        handlers(
          onQueryTasks: (request) async {
            received = request;
            return [
              AssistantTask(
                id: 't1',
                title: 'Water plants',
                dueDate: DateTime.utc(2026, 7, 11),
              ),
              const AssistantTask(
                id: 't2',
                title: 'Old chore',
                isCompleted: true,
              ),
            ];
          },
        ),
      );

      final response =
          await invokeFromNative('intent.queryTasks', {'filter': 'today'});

      expect(received!.filter, TaskQueryFilter.today);
      final list = response! as List<Object?>;
      expect(list, hasLength(2));
      final first = list.first! as Map<Object?, Object?>;
      expect(first['id'], 't1');
      expect(first['title'], 'Water plants');
      expect(first['dueDate'], '2026-07-11T00:00:00.000Z');
      expect(first['isCompleted'], isFalse);
    });

    test('unknown filter falls back to today', () async {
      QueryTasksRequest? received;
      AssistantIntents.instance.registerHandlers(
        handlers(
          onQueryTasks: (request) async {
            received = request;
            return const <AssistantTask>[];
          },
        ),
      );

      await invokeFromNative('intent.queryTasks', {'filter': 'yesterday'});

      expect(received!.filter, TaskQueryFilter.today);
    });

    test('a throwing handler yields an empty list', () async {
      AssistantIntents.instance.registerHandlers(
        handlers(onQueryTasks: (request) async => throw StateError('boom')),
      );

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {};
      addTearDown(() => FlutterError.onError = originalOnError);

      final response =
          await invokeFromNative('intent.queryTasks', {'filter': 'all'});

      expect(response, isEmpty);
    });
  });

  group('updateShortcuts', () {
    test('sends the Android labels over the channel', () async {
      await AssistantIntents.instance.updateShortcuts(
        androidShortcuts: const AndroidShortcutsConfig(
          addTaskLabel: 'Dodaj zadanie',
          queryTodayLabel: 'Na dzisiaj',
        ),
      );

      final call =
          outgoingCalls.singleWhere((c) => c.method == 'shortcuts.update');
      final args = call.arguments as Map<Object?, Object?>;
      expect(args['addTaskLabel'], 'Dodaj zadanie');
      expect(args['queryTodayLabel'], 'Na dzisiaj');
      expect(args['addTaskLongLabel'], 'Add a new task');
    });

    test('is a no-op when no platform implementation exists', () async {
      messenger.setMockMethodCallHandler(channel, null);

      await expectLater(
        AssistantIntents.instance.updateShortcuts(),
        completes,
      );
    });

    test('wraps platform errors in PlatformShortcutException', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'shortcuts_failed', message: 'nope');
      });

      await expectLater(
        AssistantIntents.instance.updateShortcuts(),
        throwsA(
          isA<PlatformShortcutException>()
              .having((e) => e.code, 'code', 'shortcuts_failed'),
        ),
      );
    });
  });
}

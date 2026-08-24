import 'package:flutter/services.dart';
import 'package:flutter_assistant_intents/flutter_assistant_intents.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(AssistantIntents.channelName);
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  /// Simulates the native side calling into the Dart handler.
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

  group('AssistantChoice', () {
    test('encodes id, title and style', () {
      const choice = AssistantChoice(
        id: 'delete',
        title: 'Delete them',
        style: AssistantChoiceStyle.destructive,
      );

      expect(choice.toMap(), {
        'id': 'delete',
        'title': 'Delete them',
        'style': 'destructive',
      });
    });

    test('defaults to the normal style', () {
      const choice = AssistantChoice(id: 'ok', title: 'OK');

      expect(choice.style, AssistantChoiceStyle.normal);
      expect(choice.toMap()['style'], 'normal');
    });

    test('the shared cancel option is styled as a cancel', () {
      expect(AssistantChoice.cancel.id, 'cancel');
      expect(AssistantChoice.cancel.style, AssistantChoiceStyle.cancel);
    });

    test('decodes a style from its wire value', () {
      expect(
        AssistantChoiceStyle.fromWire('destructive'),
        AssistantChoiceStyle.destructive,
      );
      expect(
        AssistantChoiceStyle.fromWire('cancel'),
        AssistantChoiceStyle.cancel,
      );
    });

    test('an unknown style falls back to normal rather than throwing', () {
      // A newer native side must never crash an older Dart side.
      expect(
        AssistantChoiceStyle.fromWire('holographic'),
        AssistantChoiceStyle.normal,
      );
      expect(AssistantChoiceStyle.fromWire(null), AssistantChoiceStyle.normal);
    });
  });

  group('AssistantTaskResult.needsConfirmation', () {
    const confirmation = AssistantTaskResult.needsConfirmation(
      dialog: 'Delete all completed tasks?',
      options: [
        AssistantChoice(
          id: 'delete',
          title: 'Delete them',
          style: AssistantChoiceStyle.destructive,
        ),
        AssistantChoice.cancel,
      ],
    );

    test('reports that it needs a choice', () {
      expect(confirmation.needsChoice, isTrue);
      expect(confirmation.success, isFalse);
    });

    test('a plain result does not need a choice', () {
      expect(const AssistantTaskResult.success().needsChoice, isFalse);
      expect(const AssistantTaskResult.failure('nope').needsChoice, isFalse);
    });

    test('encodes the dialog and every option', () {
      final map = confirmation.toMap();
      final payload = map['confirmation']! as Map<String, Object?>;

      expect(payload['dialog'], 'Delete all completed tasks?');
      expect(payload['options'], hasLength(2));
      expect(
        (payload['options']! as List).first,
        {'id': 'delete', 'title': 'Delete them', 'style': 'destructive'},
      );
    });

    test('supplies a safe spoken fallback when none was given', () {
      // Systems that cannot show a prompt speak this instead, and the
      // action stays unperformed.
      expect(confirmation.toMap()['message'], isNotNull);
      expect(confirmation.toMap()['message'], isA<String>());
    });

    test('honours a custom fallback message', () {
      const custom = AssistantTaskResult.needsConfirmation(
        dialog: 'Delete everything?',
        options: [AssistantChoice(id: 'yes', title: 'Yes')],
        fallbackMessage: 'Open the app to clear your list.',
      );

      expect(custom.toMap()['message'], 'Open the app to clear your list.');
    });

    test('an empty option list degrades to a plain failure', () {
      // An assistant cannot ask a question with nothing to pick, so the
      // result must not carry a half-formed prompt.
      const empty = AssistantTaskResult.needsConfirmation(
        dialog: 'Really?',
        options: [],
        fallbackMessage: 'Open the app.',
      );

      expect(empty.needsChoice, isFalse);
      expect(empty.toMap(), isNot(contains('confirmation')));
      expect(empty.toMap()['message'], 'Open the app.');
      expect(empty.success, isFalse);
    });

    test('a plain result carries no confirmation key', () {
      expect(
        const AssistantTaskResult.success(message: 'Done').toMap(),
        isNot(contains('confirmation')),
      );
    });
  });

  group('choice round-trip through the method channel', () {
    test('addTask decodes the chosen option', () async {
      String? seenChoice;
      var calls = 0;
      AssistantIntents.instance.registerHandlers(
        AssistantIntentHandlers(
          onAddTask: (request) async {
            calls++;
            seenChoice = request.choice;
            if (request.choice == null) {
              return const AssistantTaskResult.needsConfirmation(
                dialog: 'This list is full. Replace the oldest task?',
                options: [
                  AssistantChoice(id: 'replace', title: 'Replace it'),
                  AssistantChoice.cancel,
                ],
              );
            }
            return const AssistantTaskResult.success(message: 'Replaced.');
          },
        ),
      );

      // First call: no choice yet, so the handler asks.
      final first = await invokeFromNative('intent.addTask', {
        'title': 'Buy milk',
      }) as Map<Object?, Object?>;

      expect(seenChoice, isNull);
      expect(first['confirmation'], isNotNull);
      expect(first['success'], isFalse);

      // Second call: the native side replays it with the picked option.
      final second = await invokeFromNative('intent.addTask', {
        'title': 'Buy milk',
        'choice': 'replace',
      }) as Map<Object?, Object?>;

      expect(seenChoice, 'replace');
      expect(second['success'], isTrue);
      expect(second['message'], 'Replaced.');
      expect(second['confirmation'], isNull);
      expect(calls, 2);
    });

    test('completeTask decodes the chosen option', () async {
      String? seenChoice;
      AssistantIntents.instance.registerHandlers(
        AssistantIntentHandlers(
          onCompleteTask: (request) async {
            seenChoice = request.choice;
            return const AssistantTaskResult.success();
          },
        ),
      );

      await invokeFromNative('intent.completeTask', {
        'title': 'Buy milk',
        'choice': 'confirm',
      });

      expect(seenChoice, 'confirm');
    });

    test('performAction decodes the chosen option', () async {
      String? seenChoice;
      AssistantIntents.instance.registerHandlers(
        AssistantIntentHandlers(
          onAction: (request) async {
            seenChoice = request.choice;
            return const AssistantTaskResult.success();
          },
        ),
      );

      await invokeFromNative('intent.performAction', {
        'action': 'clear_completed',
        'parameters': <String, Object?>{},
        'choice': 'delete',
      });

      expect(seenChoice, 'delete');
    });

    test('a payload without a choice decodes as null, not as an error',
        () async {
      String? seenChoice = 'sentinel';
      AssistantIntents.instance.registerHandlers(
        AssistantIntentHandlers(
          onAction: (request) async {
            seenChoice = request.choice;
            return const AssistantTaskResult.success();
          },
        ),
      );

      await invokeFromNative('intent.performAction', {
        'action': 'ping',
        'parameters': <String, Object?>{},
      });

      expect(seenChoice, isNull);
    });

    test('a cancel choice reaches the handler like any other option', () async {
      String? seenChoice;
      AssistantIntents.instance.registerHandlers(
        AssistantIntentHandlers(
          onAction: (request) async {
            seenChoice = request.choice;
            return const AssistantTaskResult.success(message: 'Nothing done.');
          },
        ),
      );

      final result = await invokeFromNative('intent.performAction', {
        'action': 'clear_completed',
        'parameters': <String, Object?>{},
        'choice': 'cancel',
      }) as Map<Object?, Object?>;

      expect(seenChoice, 'cancel');
      expect(result['message'], 'Nothing done.');
    });
  });

  group('request models', () {
    test('AddTaskRequest reads the choice', () {
      final request = AddTaskRequest.fromMap({
        'title': 'Buy milk',
        'choice': 'replace',
      });

      expect(request.choice, 'replace');
      expect(request.title, 'Buy milk');
    });

    test('CompleteTaskRequest reads the choice', () {
      final request = CompleteTaskRequest.fromMap({
        'title': 'Buy milk',
        'choice': 'confirm',
      });

      expect(request.choice, 'confirm');
    });

    test('AssistantActionRequest reads the choice', () {
      final request = AssistantActionRequest.fromMap({
        'action': 'order_coffee',
        'choice': 'large',
      });

      expect(request.choice, 'large');
      expect(request.action, 'order_coffee');
    });

    test('requests built in Dart default to no choice', () {
      expect(const AddTaskRequest(title: 'x').choice, isNull);
      expect(const CompleteTaskRequest(title: 'x').choice, isNull);
      expect(const AssistantActionRequest(action: 'x').choice, isNull);
    });
  });
}

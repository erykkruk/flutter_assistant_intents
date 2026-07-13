import 'package:flutter_assistant_intents_example/main.dart' as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('example app renders the task list', (tester) async {
    await tester.pumpWidget(const example.ExampleApp());

    expect(find.text('Assistant Intents Example'), findsOneWidget);
    expect(find.text('Water the plants'), findsOneWidget);
  });
}

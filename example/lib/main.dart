import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_assistant_intents/flutter_assistant_intents.dart';

/// In-memory task store standing in for a real app's repository.
final List<AssistantTask> _tasks = <AssistantTask>[
  AssistantTask(id: '1', title: 'Water the plants', dueDate: DateTime.now()),
  const AssistantTask(id: '2', title: 'Read a book'),
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerAssistantHandlers();

  unawaited(
    AssistantIntents.instance.updateShortcuts(
      androidShortcuts: const AndroidShortcutsConfig(
        customShortcuts: [
          AndroidCustomShortcut(
            id: 'clear_completed',
            action: 'clear_completed',
            shortLabel: 'Clean up',
            longLabel: 'Clear completed tasks',
          ),
        ],
      ),
    ),
  );

  runApp(const ExampleApp());
}

/// Headless entrypoint for iOS cold-start intents: Siri can boot the Dart
/// side without the UI. Wired up in `ios/Runner/AppDelegate.swift` via
/// `FlutterAssistantIntentsPlugin.setPluginRegistrantCallback`.
@pragma('vm:entry-point')
void assistantMain() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerAssistantHandlers();
}

void _registerAssistantHandlers() {
  AssistantIntents.instance.registerHandlers(
    AssistantIntentHandlers(
      onAddTask: (request) async {
        if (request.title.isEmpty) {
          // Android shortcut launch — a real app would open its compose UI.
          return const AssistantTaskResult.failure(
            'Tell me what the task should be called.',
          );
        }
        final task = AssistantTask(
          id: '${_tasks.length + 1}',
          title: request.title,
          dueDate: request.dueDate,
        );
        _tasks.add(task);
        return AssistantTaskResult.success(
          message: "Added '${request.title}' to your list.",
          taskId: task.id,
        );
      },
      onCompleteTask: (request) async {
        final index = _tasks.indexWhere(
          (t) => t.title.toLowerCase() == request.title.toLowerCase(),
        );
        if (index == -1) {
          return AssistantTaskResult.failure(
            "I couldn't find a task called '${request.title}'.",
          );
        }
        final task = _tasks[index];
        _tasks[index] = AssistantTask(
          id: task.id,
          title: task.title,
          dueDate: task.dueDate,
          isCompleted: true,
        );
        return AssistantTaskResult.success(
          message: "Completed '${task.title}'.",
          taskId: task.id,
        );
      },
      onQueryTasks: (request) async {
        final open = _tasks.where((t) => !t.isCompleted);
        if (request.filter == TaskQueryFilter.all) {
          return open.toList();
        }
        final now = DateTime.now();
        return open
            .where(
              (t) =>
                  t.dueDate != null &&
                  t.dueDate!.year == now.year &&
                  t.dueDate!.month == now.month &&
                  t.dueDate!.day == now.day,
            )
            .toList();
      },
      // Generic action layer: backs custom iOS intents (see the
      // RunnerAppIntentsPackage note in AppDelegate.swift) and the custom
      // Android shortcut published below.
      onAction: (request) async {
        if (request.action == 'clear_completed') {
          _tasks.removeWhere((t) => t.isCompleted);
          return const AssistantTaskResult.success(
            message: 'Cleared all completed tasks.',
          );
        }
        return AssistantTaskResult.failure(
          "I don't know the action '${request.action}'.",
        );
      },
    ),
  );
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Assistant Intents Example',
      home: Scaffold(
        appBar: AppBar(title: const Text('Assistant Intents Example')),
        body: ListView(
          children: [
            for (final task in _tasks)
              ListTile(
                title: Text(task.title),
                trailing: task.isCompleted
                    ? const Icon(Icons.check)
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

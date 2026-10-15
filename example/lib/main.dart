import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_assistant_intents/flutter_assistant_intents.dart';

import 'assistant_intents.g.dart';

/// In-memory task store standing in for a real app's repository.
final List<AssistantTask> _tasks = <AssistantTask>[
  AssistantTask(id: '1', title: 'Water the plants', dueDate: DateTime.now()),
  const AssistantTask(id: '2', title: 'Read a book'),
];

/// Last answer a handler gave the assistant; the UI shows it and refreshes
/// the list, so a shortcut or Siri run is visible in the app.
final ValueNotifier<String?> _lastAssistantReply = ValueNotifier<String?>(null);

AssistantTaskResult _announce(AssistantTaskResult result) {
  _reply(result.message);
  return result;
}

void _reply(String? message) {
  // Reset first so the same answer twice still notifies the UI.
  _lastAssistantReply
    ..value = null
    ..value = message;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerAssistantHandlers();

  unawaited(
    AssistantIntents.instance.updateShortcuts(
      androidShortcuts: generatedAndroidShortcuts,
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
          return _announce(
            const AssistantTaskResult.failure(
              'Tell me what the task should be called.',
            ),
          );
        }
        final task = AssistantTask(
          id: '${_tasks.length + 1}',
          title: request.title,
          dueDate: request.dueDate,
        );
        _tasks.add(task);
        return _announce(
          AssistantTaskResult.success(
            message: "Added '${request.title}' to your list.",
            taskId: task.id,
          ),
        );
      },
      onCompleteTask: (request) async {
        final index = _tasks.indexWhere(
          (t) => t.title.toLowerCase() == request.title.toLowerCase(),
        );
        if (index == -1) {
          return _announce(
            AssistantTaskResult.failure(
              "I couldn't find a task called '${request.title}'.",
            ),
          );
        }
        final task = _tasks[index];
        _tasks[index] = AssistantTask(
          id: task.id,
          title: task.title,
          dueDate: task.dueDate,
          isCompleted: true,
        );
        return _announce(
          AssistantTaskResult.success(
            message: "Completed '${task.title}'.",
            taskId: task.id,
          ),
        );
      },
      onQueryTasks: (request) async {
        final open = _tasks.where((t) => !t.isCompleted);
        _reply("Showing ${request.filter.name}'s tasks.");
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
        if (request.action == clearCompletedAction) {
          _tasks.removeWhere((t) => t.isCompleted);
          return _announce(
            const AssistantTaskResult.success(
              message: 'Cleared all completed tasks.',
            ),
          );
        }
        return _announce(
          AssistantTaskResult.failure(
            "I don't know the action '${request.action}'.",
          ),
        );
      },
    ),
  );
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Assistant Intents Example',
      home: TaskListPage(),
    );
  }
}

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  @override
  void initState() {
    super.initState();
    _lastAssistantReply.addListener(_showAssistantReply);
  }

  @override
  void dispose() {
    _lastAssistantReply.removeListener(_showAssistantReply);
    super.dispose();
  }

  void _showAssistantReply() {
    final reply = _lastAssistantReply.value;
    setState(() {});
    if (reply == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Assistant: $reply')));
  }

  void _addTaskFromUi() {
    final title = 'Task ${_tasks.length + 1}';
    setState(() {
      _tasks.add(AssistantTask(id: '${_tasks.length + 1}', title: title));
    });
    // The user did this in the app, so let the system learn it: Siri
    // Suggestions / Spotlight on iOS, shortcut ranking on Android.
    unawaited(AssistantIntents.instance.donateAddTask(title: title));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addTaskFromUi,
        tooltip: 'Add task',
        child: const Icon(Icons.add),
      ),
    );
  }
}

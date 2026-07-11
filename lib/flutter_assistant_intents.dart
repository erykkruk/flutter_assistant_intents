/// Expose task-app actions to voice assistants — iOS App Intents (Siri,
/// Spotlight, Shortcuts) and Android app shortcuts — with typed Dart
/// handlers.
///
/// See [AssistantIntents] for the entry point.
library flutter_assistant_intents;

export 'src/assistant_intents.dart' show AssistantIntents;
export 'src/exceptions.dart'
    show
        AssistantIntentsException,
        InvalidIntentPayloadException,
        PlatformShortcutException;
export 'src/handlers.dart'
    show
        AddTaskHandler,
        AssistantIntentHandlers,
        CompleteTaskHandler,
        QueryTasksHandler;
export 'src/models/add_task_request.dart' show AddTaskRequest;
export 'src/models/android_shortcuts_config.dart' show AndroidShortcutsConfig;
export 'src/models/assistant_task.dart' show AssistantTask;
export 'src/models/assistant_task_result.dart' show AssistantTaskResult;
export 'src/models/complete_task_request.dart' show CompleteTaskRequest;
export 'src/models/query_tasks_request.dart' show QueryTasksRequest;
export 'src/models/task_query_filter.dart' show TaskQueryFilter;

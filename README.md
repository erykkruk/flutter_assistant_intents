# flutter_assistant_intents

Expose task-app actions to voice assistants from any Flutter task/todo app —
**iOS App Intents** (Siri, Spotlight, the Shortcuts app) and **Android app
shortcuts** — through one typed Dart handler API. Product-agnostic: no app
names are baked in; iOS phrases use the application-name token and Android
labels are passed in (and localizable) from Dart.

## Support matrix

| Capability | iOS | Android |
|---|---|---|
| Voice: "Add a task in `<app>`" (with spoken title + due date) | ✅ App Intents, iOS 16+ | ❌ (AppFunctions later, see below) |
| Voice: "Complete a task in `<app>`" | ✅ App Intents | ❌ |
| Voice: "What are my tasks in `<app>`" (assistant speaks the list) | ✅ App Intents | ❌ |
| Shortcuts app / automations | ✅ | — |
| Spotlight / zero-setup phrase suggestions | ✅ (`AppShortcutsProvider`) | — |
| Launcher shortcuts: "Add task", "Today's tasks" (launch into the app) | — | ✅ `ShortcutManagerCompat` dynamic shortcuts |
| AppFunctions (Gemini-invokable in-app functions) | — | 🚧 planned — `androidx.appfunctions` is beta and Samsung-only before Android 17; a clearly marked stub (`appfunctions/AppFunctionsIntegration.kt`) documents the wiring |

SiriKit custom intents are deliberately not used — App Intents is the modern
replacement (SiriKit intents are deprecated as of iOS 26).

## Quick start

```yaml
dependencies:
  flutter_assistant_intents: ^0.1.0
```

Register handlers early in startup (they must be in place before an intent
arrives) and refresh shortcut donations:

```dart
import 'package:flutter_assistant_intents/flutter_assistant_intents.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  AssistantIntents.instance.registerHandlers(
    AssistantIntentHandlers(
      onAddTask: (request) async {
        final task = await repository.create(request.title, due: request.dueDate);
        return AssistantTaskResult.success(
          message: "Added '${request.title}' to your list.",
          taskId: task.id,
        );
      },
      onCompleteTask: (request) async {
        final task = await repository.findByTitle(request.title);
        if (task == null) {
          return AssistantTaskResult.failure(
            "I couldn't find a task called '${request.title}'.",
          );
        }
        await repository.complete(task.id);
        return AssistantTaskResult.success(message: "Completed '${task.title}'.");
      },
      onQueryTasks: (request) async => request.filter == TaskQueryFilter.today
          ? repository.dueToday()
          : repository.allOpen(),
    ),
  );

  unawaited(AssistantIntents.instance.updateShortcuts());
  runApp(const MyApp());
}
```

Rules of thumb:

- Handlers should **never throw** — return `AssistantTaskResult.failure('…')`
  with a short, speakable sentence. Thrown errors are converted into a
  generic failure and reported via `FlutterError.reportError`.
- When the user is logged out, return a friendly failure like
  `"Please open the app and sign in first."`.
- `result.message` is spoken by Siri verbatim — keep it short and free of
  technical detail.

## iOS setup (host app)

The plugin requires **iOS 16.0+** (set `platform :ios, '16.0'` in your
Podfile and the Runner deployment target).

App Intents metadata is extracted from the **app target** at build time.
Intents defined inside this plugin (a library) are only discovered when the
host app re-exports them through an `AppIntentsPackage` (Xcode 15+, runtime
iOS 16.4+). Add this once to your Runner target:

```swift
import AppIntents
import flutter_assistant_intents

@available(iOS 16.4, *)
struct RunnerAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [FlutterAssistantIntentsPackage.self]
    }
}
```

> **iOS 16.0–16.3 caveat:** package-provided intents require iOS 16.4. If you
> must support 16.0–16.3, declare thin wrapper intents in the Runner target
> that call the plugin's public `AssistantIntentBridge` — the wrappers live in
> the app target, so metadata extraction sees them on any iOS 16 device.

### Cold start limitation

Intents run in the app process (`openAppWhenRun = false`). If the app is not
running, iOS launches it in the background and the plugin waits **up to 5
seconds** for your Dart code to call `registerHandlers`. If your bootstrap
takes longer (or registration is gated behind UI), the assistant answers
with *"Please open the app first, then try again."*

The code is structured so a headless background engine (registering handlers
without full app bootstrap) can be added later without breaking the API —
today the pragmatic requirement is: **register handlers as early as possible
in `main()`**.

## Android setup (host app)

No manifest changes are required for dynamic shortcuts. Call
`updateShortcuts()` on startup (pass localized labels):

```dart
await AssistantIntents.instance.updateShortcuts(
  androidShortcuts: const AndroidShortcutsConfig(
    addTaskLabel: 'Add task',
    queryTodayLabel: "Today's tasks",
  ),
);
```

Tapping a shortcut launches (or resumes) the app with an intent extra that
the plugin converts into the same Dart handler calls:

- **Add task** → `onAddTask` with an **empty title** (shortcuts cannot carry
  free-form text) — treat it as "open the add-task flow".
- **Today's tasks** → `onQueryTasks` with `TaskQueryFilter.today` — navigate
  to your today view.

If your `MainActivity` overrides `onNewIntent`, keep calling
`super.onNewIntent(intent)` so plugin listeners receive it (the default
`FlutterActivity` already does).

## API surface

| Symbol | Purpose |
|---|---|
| `AssistantIntents.instance` | Entry point (singleton) |
| `registerHandlers(AssistantIntentHandlers)` | Wire your app's task logic |
| `updateShortcuts({AndroidShortcutsConfig})` | Refresh platform shortcut donations (no-op-safe everywhere) |
| `AddTaskRequest` | `title`, `dueDate?`, `notes?` |
| `CompleteTaskRequest` | `title` (resolve fuzzily in your app) |
| `QueryTasksRequest` | `filter` (`TaskQueryFilter.today` / `.all`) |
| `AssistantTask` | `id`, `title`, `dueDate?`, `isCompleted` |
| `AssistantTaskResult` | `.success(message:, taskId:)` / `.failure(message)` |

## Example

See [`example/`](example/lib/main.dart) for a minimal in-memory app.

## License

MIT

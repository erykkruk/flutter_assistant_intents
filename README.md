# flutter_assistant_intents

Expose app actions to voice assistants — **iOS App Intents** (Siri,
Spotlight, the Shortcuts app) and **Android app shortcuts** — through one
typed Dart handler API.

Two layers, mix freely:

- **Task preset** (batteries included): `onAddTask` / `onCompleteTask` /
  `onQueryTasks` back ready-made Siri intents and launcher shortcuts for
  task/todo apps. Product-agnostic — iOS phrases use the application-name
  token, Android labels are passed in (and localizable) from Dart.
- **Generic action layer** (any app domain): register `onAction` in Dart and
  route *your own* intents to it — custom iOS `AppIntent`s with your own Siri
  phrases (one small Swift declaration each, template below) and fully
  Dart-defined custom Android shortcuts.

> **Why the Swift declaration?** App Intents metadata is compiled statically
> — Siri discovers intent *types* and phrases at build time, so no plugin can
> create new intent types at runtime from Dart. This is an Apple platform
> constraint, not a library choice. The split this plugin makes is: intent
> *type + phrases* in Swift (a few lines, no logic), all *fulfillment logic,
> parameters and results* in Dart. On Android, custom shortcuts are 100%
> Dart-defined.

## Support matrix

| Capability | iOS | Android |
|---|---|---|
| Voice: "Add a task in `<app>`" (spoken title + due date + notes) | ✅ App Intents, iOS 16+ ¹ | ❌ (AppFunctions later, see below) |
| Voice: "Complete a task in `<app>`" | ✅ ¹ | ❌ |
| Voice: "What are my tasks in `<app>`" (assistant speaks the list) | ✅ ¹ | ❌ |
| Custom app-defined actions (any domain) | ✅ custom intent in Runner → `onAction` ¹ | ✅ custom shortcut → `onAction` |
| Shortcuts app / automations | ✅ | — |
| Siri phrase suggestions (`AppShortcutsProvider`) | ✅ | — |
| Launcher shortcuts (launch into the app) | — | ✅ `ShortcutManagerCompat.pushDynamicShortcut` |
| AppFunctions (assistant-invokable in-app functions) | — | 🚧 planned — `androidx.appfunctions` is **alpha**; a clearly marked stub (`appfunctions/AppFunctionsIntegration.kt`) documents the wiring and its host-app KSP requirement |

¹ Works even from a **cold start** (app process not running) once the
one-line headless-engine callback is configured — see
[Cold start](#cold-start). Without it, intents require the app process to be
alive (foreground or suspended).

SiriKit custom intents are deliberately not used — App Intents is the modern
replacement (SiriKit intents are deprecated as of iOS 26).

## Quick start

```yaml
dependencies:
  flutter_assistant_intents: ^1.0.0
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

All handlers are optional (register at least one). Rules of thumb:

- Handlers should **never throw** — return `AssistantTaskResult.failure('…')`
  with a short, speakable sentence. Thrown errors are converted into a
  generic failure and reported via `FlutterError.reportError`.
- When the user is logged out, return a friendly failure like
  `"Please open the app and sign in first."`.
- `result.message` is spoken by Siri verbatim — keep it short and free of
  technical detail.

## Generic actions — expose any app domain

Register a single `onAction` handler and dispatch on your own action ids:

```dart
AssistantIntents.instance.registerHandlers(
  AssistantIntentHandlers(
    onAction: (request) async => switch (request.action) {
      'order_coffee' => await _orderCoffee(request.parameters['size'] as String?),
      'clear_completed' => await _clearCompleted(),
      _ => const AssistantTaskResult.failure('Unknown action.'),
    },
  ),
);
```

**Android** — publish custom shortcuts entirely from Dart:

```dart
await AssistantIntents.instance.updateShortcuts(
  androidShortcuts: const AndroidShortcutsConfig(
    publishTaskShortcuts: false, // skip the task preset if you don't need it
    customShortcuts: [
      AndroidCustomShortcut(
        id: 'coffee',
        action: 'order_coffee',
        shortLabel: 'Coffee',
        longLabel: 'Order a coffee',
      ),
    ],
  ),
);
```

**iOS** — declare one small intent per action in your Runner target (this is
where the Siri phrases live; the logic stays in Dart):

```swift
import AppIntents
import flutter_assistant_intents

@available(iOS 16.0, *)
struct OrderCoffeeIntent: AppIntent {
    static var title: LocalizedStringResource = "Order Coffee"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Size")
    var size: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try await AssistantIntentBridge.shared.performAction(
            id: "order_coffee",
            parameters: ["size": size as Any]
        )
        return .result(dialog: IntentDialog(
            stringLiteral: result.message ?? (result.success ? "Done." : "Sorry, that failed.")
        ))
    }
}

@available(iOS 16.0, *)
struct MyAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OrderCoffeeIntent(),
            phrases: ["Order a coffee in \(.applicationName)"],
            shortTitle: "Order Coffee",
            systemImageName: "cup.and.saucer"
        )
    }
}
```

See [`example/ios/Runner/AppDelegate.swift`](example/ios/Runner/AppDelegate.swift)
for a complete, working declaration.

## iOS setup (host app)

The plugin requires **iOS 16.0+** (set `platform :ios, '16.0'` in your
Podfile and the Runner deployment target).

App Intents metadata is extracted from the **app target** at build time.
Intents defined inside this plugin (a library) are only discovered when the
host app re-exports them through an `AppIntentsPackage` (current SDKs mark
the protocol iOS 17.0+). Add this once to your Runner target:

```swift
import AppIntents
import flutter_assistant_intents

@available(iOS 17.0, *)
struct RunnerAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [FlutterAssistantIntentsPackage.self]
    }
}
```

> **iOS 16.x caveat:** the `AppIntentsPackage` re-export requires iOS 17.
> To surface the built-in intents on iOS 16 devices, declare thin wrapper
> intents in the Runner target that call the plugin's public
> `AssistantIntentBridge` — the wrappers live in the app target, so metadata
> extraction sees them on any iOS 16 device.

> **`use_frameworks!` / release-build caveat:** metadata extraction from
> intents living in an embedded framework has known gaps in some
> release/TestFlight configurations. If the built-in intents don't appear in
> the Shortcuts app of a release build, declare thin wrapper intents in the
> Runner (same pattern as above) — wrappers in the app target are always
> extracted. Custom intents you declare via the generic action layer live in
> the Runner already and are unaffected.

### Cold start

Intents run in the app process (`openAppWhenRun = false`) and are fulfilled
by your Dart handlers, so the Flutter engine must be running. When Siri runs
an intent while the process is cold, the plugin can **boot a headless
Flutter engine** — enable it with one call in
`application(_:didFinishLaunchingWithOptions:)`:

```swift
FlutterAssistantIntentsPlugin.setPluginRegistrantCallback { engine in
    GeneratedPluginRegistrant.register(with: engine)
}
```

By default the headless engine runs your `main()`. If your `main()` does
work that is unsafe without UI (or you want a faster boot), point it at a
dedicated entrypoint that only registers the handlers:

```swift
FlutterAssistantIntentsPlugin.setPluginRegistrantCallback(entrypoint: "assistantMain") { engine in
    GeneratedPluginRegistrant.register(with: engine)
}
```

```dart
@pragma('vm:entry-point')
void assistantMain() {
  WidgetsFlutterBinding.ensureInitialized();
  registerMyAssistantHandlers(); // same registration main() uses
}
```

Without the callback, cold-start intents answer *"Please open the app first,
then try again."* (the plugin waits up to 5 seconds for `registerHandlers`
and a further 10 seconds for each handler reply — it never hangs Siri).
Either way: **register handlers as early as possible** so warm/background
launches always succeed.

## Android setup (host app)

No manifest changes are required for dynamic shortcuts. Call
`updateShortcuts()` on startup (pass localized labels):

```dart
await AssistantIntents.instance.updateShortcuts(
  androidShortcuts: const AndroidShortcutsConfig(
    addTaskLabel: 'Add task',
    queryTodayLabel: 'Today',
  ),
);
```

Notes:

- Shortcuts are published with `pushDynamicShortcut` (additive) — the plugin
  **never touches shortcuts your app publishes itself**.
- Keep short labels under ~10 characters; launchers truncate longer ones.
- Labels are supplied from Dart, so **re-call `updateShortcuts()` after a
  locale change** to re-publish translated labels.
- To surface the shortcuts on Google surfaces (Assistant/Gemini "shortcuts"
  suggestions), add `androidx.core:core-google-shortcuts` to your app —
  donation then happens automatically for pushed shortcuts. The plugin does
  not impose that dependency.

Tapping a shortcut launches (or resumes) the app with an intent extra that
the plugin converts into the same Dart handler calls:

- **Add task** → `onAddTask` with an **empty title** (shortcuts cannot carry
  free-form text) — treat it as "open the add-task flow".
- **Today** → `onQueryTasks` with `TaskQueryFilter.today` — navigate to your
  today view.
- **Custom shortcut** → `onAction` with the shortcut's `action` id.

If your `MainActivity` overrides `onNewIntent`, keep calling
`super.onNewIntent(intent)` so plugin listeners receive it (the default
`FlutterActivity` already does).

## API surface

| Symbol | Purpose |
|---|---|
| `AssistantIntents.instance` | Entry point (singleton) |
| `registerHandlers(AssistantIntentHandlers)` | Wire your app's logic (all handlers optional, min. one) |
| `updateShortcuts({AndroidShortcutsConfig})` | Refresh platform shortcut donations (no-op-safe everywhere) |
| `AddTaskRequest` | `title`, `dueDate?`, `notes?` |
| `CompleteTaskRequest` | `title` (resolve fuzzily in your app) |
| `QueryTasksRequest` | `filter` (`TaskQueryFilter.today` / `.all`) |
| `AssistantActionRequest` | `action` id + `parameters` map (generic layer) |
| `AssistantTask` | `id`, `title`, `dueDate?`, `isCompleted` |
| `AssistantTaskResult` | `.success(message:, taskId:)` / `.failure(message)` |
| `AndroidShortcutsConfig` / `AndroidCustomShortcut` | Android shortcut labels + custom shortcuts |

## Example

See [`example/`](example/lib/main.dart) for a runnable app using both the
task preset and the generic action layer.

## License

MIT

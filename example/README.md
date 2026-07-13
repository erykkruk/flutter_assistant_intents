# flutter_assistant_intents example

Minimal in-memory task app wired to `flutter_assistant_intents`:

- **Task preset** — `onAddTask` / `onCompleteTask` / `onQueryTasks` back the
  built-in Siri intents (iOS) and the "Add task" / "Today" launcher
  shortcuts (Android).
- **Generic action layer** — the `clear_completed` action is fulfilled in
  Dart (`onAction`) and exposed as a custom iOS intent with its own Siri
  phrases (`ios/Runner/AppDelegate.swift`) and a custom Android shortcut.

Run on a device:

```bash
flutter run
```

On iOS, `AppDelegate.swift` also shows the required one-time
`AppIntentsPackage` re-export that makes the plugin's built-in intents
visible to App Intents metadata extraction.

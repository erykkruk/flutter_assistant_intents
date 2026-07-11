# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-11

### Added

- Typed Dart handler API: `AssistantIntents.instance.registerHandlers(...)`
  with `onAddTask`, `onCompleteTask` and `onQueryTasks` callbacks.
- Typed models: `AddTaskRequest`, `CompleteTaskRequest`, `QueryTasksRequest`,
  `AssistantTask`, `AssistantTaskResult`, `TaskQueryFilter`.
- iOS (16+): App Intents implementation — `AddTaskIntent`,
  `CompleteTaskIntent`, `QueryTasksIntent`, an `AppShortcutsProvider` with
  app-name-based invocation phrases, and `FlutterAssistantIntentsPackage`
  (`AppIntentsPackage`) for host re-export.
- Android: dynamic app shortcuts ("Add task", "Show today's tasks") via
  `ShortcutManagerCompat`, routed back into the same Dart handlers on launch.
- `updateShortcuts()` — no-op-safe refresh of platform shortcut donations
  with configurable Android shortcut labels.
- Dart-layer tests with a mocked method channel.

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-07-13

### Added

- **Swift Package Manager support** on iOS (dual with CocoaPods): sources
  moved to `ios/flutter_assistant_intents/Sources/…` with a `Package.swift`;
  the podspec points at the same sources, so both integrations work.

## [1.1.0] - 2026-07-13

### Added

- **iOS cold-start support**: the plugin can boot a headless `FlutterEngine`
  when Siri runs an intent while the app process is not alive. Enable with
  `FlutterAssistantIntentsPlugin.setPluginRegistrantCallback` (optionally
  with a dedicated Dart `entrypoint`); a `handlers.sync` handshake removes
  the engine-boot race.

## [1.0.0] - 2026-07-13

First stable release — API considered stable from here on (SemVer).

### Changed

- Promoted 0.1.0 to stable with no API changes: task preset
  (`onAddTask` / `onCompleteTask` / `onQueryTasks`) + generic action layer
  (`onAction`, custom iOS intents via `AssistantIntentBridge.performAction`,
  Dart-defined custom Android shortcuts).

## [0.1.0] - 2026-07-13

### Added

- Typed Dart handler API: `AssistantIntents.instance.registerHandlers(...)`
  with optional `onAddTask`, `onCompleteTask`, `onQueryTasks` callbacks
  (task preset) and a generic `onAction` callback for app-defined actions.
- Typed models: `AddTaskRequest`, `CompleteTaskRequest`, `QueryTasksRequest`,
  `AssistantActionRequest`, `AssistantTask`, `AssistantTaskResult`,
  `TaskQueryFilter`, `AndroidShortcutsConfig`, `AndroidCustomShortcut`.
- iOS (16+): App Intents implementation — `AddTaskIntent` (title, due date,
  notes), `CompleteTaskIntent`, `QueryTasksIntent`, an `AppShortcutsProvider`
  with app-name-based invocation phrases (short titles + SF Symbols), and
  `FlutterAssistantIntentsPackage` (`AppIntentsPackage`) for host re-export.
- iOS: public `AssistantIntentBridge.performAction(id:parameters:)` so host
  apps can declare custom intents with their own Siri phrases whose logic
  lives in Dart; hard 10 s timeout on every Dart round-trip so a silent
  handler can never hang Siri.
- Android: dynamic app shortcuts ("Add task", "Today") published additively
  via `ShortcutManagerCompat.pushDynamicShortcut` (host shortcuts are never
  replaced), with icons and ranks; fully Dart-defined custom shortcuts
  routed to `onAction`.
- `updateShortcuts()` — no-op-safe refresh of platform shortcut donations
  with configurable Android labels, task-preset opt-out and custom
  shortcuts.
- Runnable `example/` app (Android + iOS hosts) demonstrating the task
  preset, the generic action layer and the required iOS
  `AppIntentsPackage` re-export.
- Dart-layer tests with a mocked method channel.

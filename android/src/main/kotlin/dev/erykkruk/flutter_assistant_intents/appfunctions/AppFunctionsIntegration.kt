package dev.erykkruk.flutter_assistant_intents.appfunctions

/**
 * EXPERIMENTAL — NOT WIRED YET.
 *
 * Placeholder for the Android AppFunctions integration, the platform's
 * upcoming equivalent of iOS App Intents (assistant-invokable in-app
 * functions with typed parameters).
 *
 * Status as of mid-2026: `androidx.appfunctions` is in beta and only
 * honored by Samsung devices (Bixby) before Android 17; Gemini/Assistant
 * support lands with Android 17. Shipping it now would add a beta AndroidX
 * dependency for a feature almost no device can use, so the stable MVP is
 * dynamic app shortcuts (see `ShortcutsPublisher`).
 *
 * Planned wiring when the artifact stabilizes:
 * - Add `androidx.appfunctions:appfunctions:*` (+ its ksp compiler
 *   `androidx.appfunctions:appfunctions-compiler`) to `build.gradle`.
 * - Declare `@AppFunction` implementations for addTask / completeTask /
 *   queryTasks that forward to the existing method-channel bridge in
 *   `FlutterAssistantIntentsPlugin` (same wire contract as iOS:
 *   `intent.addTask`, `intent.completeTask`, `intent.queryTasks`).
 * - Register the generated AppFunctionService in the plugin manifest.
 *
 * The Dart API is already shaped for this — no breaking changes expected.
 */
internal object AppFunctionsIntegration

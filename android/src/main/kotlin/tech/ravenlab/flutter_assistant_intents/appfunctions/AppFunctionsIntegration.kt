package tech.ravenlab.flutter_assistant_intents.appfunctions

/**
 * EXPERIMENTAL — NOT WIRED YET.
 *
 * Placeholder for the Android AppFunctions integration, the platform's
 * upcoming equivalent of iOS App Intents (assistant-invokable in-app
 * functions with typed parameters).
 *
 * Status as of mid-2026: `androidx.appfunctions` is in **alpha**
 * (1.0.0-alpha10, no beta or stable release). `AppFunctionManagerCompat`
 * targets API 34+ devices and the platform `android.app.appfunctions` stack
 * shipped with API 36 (Android 16); which assistants invoke app functions
 * on which devices is still OEM-dependent. Shipping it now would add an
 * alpha AndroidX dependency for a feature almost no device can use, so the
 * stable MVP is dynamic app shortcuts (see `ShortcutsPublisher`).
 *
 * Planned wiring when the artifact stabilizes:
 * - Add `androidx.appfunctions:appfunctions` + `appfunctions-service` and
 *   its KSP compiler (`androidx.appfunctions:appfunctions-compiler`).
 * - Declare `@AppFunction` implementations for addTask / completeTask /
 *   queryTasks that forward to the existing method-channel bridge in
 *   `FlutterAssistantIntentsPlugin` (same wire contract as iOS:
 *   `intent.addTask`, `intent.completeTask`, `intent.queryTasks`).
 * - Register the generated AppFunctionService in the plugin manifest.
 *
 * Caveat: the KSP compiler runs at **host-app** compile time, so hosts will
 * need the KSP Gradle plugin and the appfunctions wiring in their own app
 * module — this cannot ship transparently inside a prebuilt plugin AAR.
 * The Dart API is already shaped for this — no Dart-side breaking changes
 * expected.
 */
internal object AppFunctionsIntegration

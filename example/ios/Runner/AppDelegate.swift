import AppIntents
import Flutter
import UIKit
import flutter_assistant_intents

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

/// Re-exports the plugin's built-in task intents so App Intents metadata
/// extraction finds them (required once per host app, iOS 17.0+).
@available(iOS 17.0, *)
struct RunnerAppIntentsPackage: AppIntentsPackage {
  static var includedPackages: [any AppIntentsPackage.Type] {
    [FlutterAssistantIntentsPackage.self]
  }
}

/// A custom, app-defined intent using the generic action layer: the intent
/// type and Siri phrases live here (App Intents metadata is compiled
/// statically), while the fulfillment logic is the `onAction` handler
/// registered in Dart under the same action id.
@available(iOS 16.0, *)
struct ClearCompletedTasksIntent: AppIntent {
  static var title: LocalizedStringResource = "Clear Completed Tasks"
  static var description = IntentDescription("Removes all completed tasks from the list.")
  static var openAppWhenRun: Bool = false

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let result = try await AssistantIntentBridge.shared.performAction(id: "clear_completed")
    return .result(dialog: IntentDialog(
      stringLiteral: result.message ?? (result.success ? "Done." : "Sorry, that failed.")
    ))
  }
}

/// Siri phrases for the custom intent above.
@available(iOS 16.0, *)
struct RunnerShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: ClearCompletedTasksIntent(),
      phrases: [
        "Clean up my tasks in \(.applicationName)",
        "Clear completed tasks in \(.applicationName)",
      ],
      shortTitle: "Clean Up",
      systemImageName: "trash.circle"
    )
  }
}

import Flutter
import UIKit

public class FlutterAssistantIntentsPlugin: NSObject, FlutterPlugin {

    private static let channelName = "tech.ravenlab/flutter_assistant_intents"

    /// Enables **cold-start** intent handling: when Siri runs an intent while
    /// the app process has no Flutter engine, the plugin boots a headless
    /// `FlutterEngine` running [entrypoint] and hands it to [callback] so the
    /// host can register its plugins. Call once, early in
    /// `application(_:didFinishLaunchingWithOptions:)`:
    ///
    /// ```swift
    /// FlutterAssistantIntentsPlugin.setPluginRegistrantCallback { engine in
    ///     GeneratedPluginRegistrant.register(with: engine)
    /// }
    /// ```
    ///
    /// [entrypoint] defaults to `"main"`. If your `main()` does work that is
    /// unsafe without UI, point it at a dedicated top-level function (mark it
    /// `@pragma('vm:entry-point')` in Dart) that only registers the assistant
    /// handlers.
    ///
    /// Without this callback the plugin cannot register plugins on a new
    /// engine, so cold-start intents answer "Please open the app first."
    public static func setPluginRegistrantCallback(
        entrypoint: String = "main",
        _ callback: @escaping (FlutterEngine) -> Void
    ) {
        AssistantIntentBridge.shared.configureHeadlessBoot(
            entrypoint: entrypoint,
            registrant: callback
        )
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = FlutterAssistantIntentsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        AssistantIntentBridge.shared.attach(channel: channel)
        // Handshake for the boot race: if the Dart side registered its
        // handlers before this plugin attached (headless engine start),
        // 'handlers.registered' was sent into the void — ask directly.
        channel.invokeMethod("handlers.sync", arguments: nil) { response in
            if let ready = response as? Bool, ready {
                AssistantIntentBridge.shared.markHandlersRegistered()
            }
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "handlers.registered":
            AssistantIntentBridge.shared.markHandlersRegistered()
            result(nil)

        case "shortcuts.update":
            // Android publishes dynamic shortcuts here; on iOS the App
            // Shortcuts are static metadata, we only refresh parameter-based
            // phrase suggestions.
            if #available(iOS 16.0, *) {
                AssistantShortcuts.updateAppShortcutParameters()
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

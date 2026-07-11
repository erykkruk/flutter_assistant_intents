import Flutter
import UIKit

public class FlutterAssistantIntentsPlugin: NSObject, FlutterPlugin {

    private static let channelName = "dev.erykkruk/flutter_assistant_intents"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = FlutterAssistantIntentsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        AssistantIntentBridge.shared.attach(channel: channel)
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

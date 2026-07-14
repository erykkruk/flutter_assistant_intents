import Flutter
import UIKit
import flutter_assistant_intents

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Cold-start support: lets the plugin boot a headless Flutter engine
    // (running the dedicated `assistantMain` entrypoint) when Siri runs an
    // intent while the app process is not alive.
    FlutterAssistantIntentsPlugin.setPluginRegistrantCallback(entrypoint: "assistantMain") { engine in
      GeneratedPluginRegistrant.register(with: engine)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

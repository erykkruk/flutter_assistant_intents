import Flutter
import Foundation

/// Error surfaced to the assistant when an intent cannot be fulfilled.
enum AssistantBridgeError: Error, LocalizedError {
    /// The Flutter engine is not running / the app has not registered
    /// handlers yet (cold start), and the grace period elapsed.
    case appNotReady
    /// The Dart handler answered with a platform error.
    case dartError(String)
    /// The Dart handler returned a payload we could not decode.
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .appNotReady:
            return "Please open the app first, then try again."
        case .dartError(let message):
            return message
        case .invalidPayload:
            return "Something went wrong. Please try again in the app."
        }
    }
}

/// Decoded result of an add/complete handler call into Dart.
struct AssistantResultPayload {
    let success: Bool
    let message: String?
    let taskId: String?

    init(from value: Any?) {
        let map = value as? [String: Any] ?? [:]
        self.success = map["success"] as? Bool ?? false
        self.message = map["message"] as? String
        self.taskId = map["taskId"] as? String
    }
}

/// Decoded task returned by the Dart query handler.
struct AssistantTaskPayload {
    let id: String
    let title: String
    let dueDate: Date?
    let isCompleted: Bool

    init?(from value: Any?) {
        guard let map = value as? [String: Any],
              let id = map["id"] as? String,
              let title = map["title"] as? String
        else { return nil }
        self.id = id
        self.title = title
        self.isCompleted = map["isCompleted"] as? Bool ?? false
        if let raw = map["dueDate"] as? String {
            self.dueDate = AssistantIntentBridge.iso8601.date(from: raw)
        } else {
            self.dueDate = nil
        }
    }
}

/// Bridges App Intents (which run inside the app process) to the Dart
/// handlers registered via `AssistantIntents.registerHandlers`.
///
/// Cold start: when Siri launches the app in the background to run an
/// intent, the Flutter engine boots through the normal app launch path. The
/// bridge waits up to `handlerTimeout` for Dart to register its handlers;
/// past that, the intent fails with a friendly "open the app first" dialog.
final class AssistantIntentBridge {

    static let shared = AssistantIntentBridge()

    /// ISO-8601 with fractional seconds first, plain fallback — matches
    /// Dart's `DateTime.toIso8601String()` output.
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let handlerTimeout: TimeInterval = 5.0
    private static let pollInterval: UInt64 = 100_000_000 // 100 ms

    private let stateQueue = DispatchQueue(
        label: "dev.erykkruk.flutter_assistant_intents.bridge"
    )
    private var channel: FlutterMethodChannel?
    private var handlersRegistered = false

    private init() {}

    func attach(channel: FlutterMethodChannel) {
        stateQueue.sync {
            self.channel = channel
            // A new engine means Dart must register handlers again.
            self.handlersRegistered = false
        }
    }

    func markHandlersRegistered() {
        stateQueue.sync { self.handlersRegistered = true }
    }

    // MARK: - Intent entry points

    func performAddTask(title: String, dueDate: Date?, notes: String?) async throws
        -> AssistantResultPayload
    {
        var arguments: [String: Any] = ["title": title]
        if let dueDate = dueDate {
            arguments["dueDate"] = Self.iso8601.string(from: dueDate)
        }
        if let notes = notes {
            arguments["notes"] = notes
        }
        let response = try await invokeDart(method: "intent.addTask", arguments: arguments)
        return AssistantResultPayload(from: response)
    }

    func performCompleteTask(title: String) async throws -> AssistantResultPayload {
        let response = try await invokeDart(
            method: "intent.completeTask",
            arguments: ["title": title]
        )
        return AssistantResultPayload(from: response)
    }

    func performQueryTasks(filter: String) async throws -> [AssistantTaskPayload] {
        let response = try await invokeDart(
            method: "intent.queryTasks",
            arguments: ["filter": filter]
        )
        guard let list = response as? [Any] else {
            throw AssistantBridgeError.invalidPayload
        }
        return list.compactMap { AssistantTaskPayload(from: $0) }
    }

    // MARK: - Channel plumbing

    private func isReady() -> Bool {
        stateQueue.sync { handlersRegistered && channel != nil }
    }

    private func waitForHandlers() async -> Bool {
        let deadline = Date().addingTimeInterval(Self.handlerTimeout)
        while Date() < deadline {
            if isReady() { return true }
            try? await Task.sleep(nanoseconds: Self.pollInterval)
        }
        return isReady()
    }

    private func invokeDart(method: String, arguments: [String: Any]) async throws -> Any? {
        guard await waitForHandlers(),
              let channel = stateQueue.sync(execute: { self.channel })
        else {
            throw AssistantBridgeError.appNotReady
        }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                channel.invokeMethod(method, arguments: arguments) { response in
                    if let error = response as? FlutterError {
                        continuation.resume(
                            throwing: AssistantBridgeError.dartError(
                                error.message ?? "The app could not handle this request."
                            )
                        )
                    } else if let sentinel = response as? NSObject,
                              sentinel === FlutterMethodNotImplemented
                    {
                        continuation.resume(throwing: AssistantBridgeError.appNotReady)
                    } else {
                        continuation.resume(returning: response)
                    }
                }
            }
        }
    }
}

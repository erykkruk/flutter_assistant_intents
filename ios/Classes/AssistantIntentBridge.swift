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

/// Decoded result of a Dart handler call. Public so host apps can declare
/// their own custom `AppIntent`s that call `AssistantIntentBridge`.
public struct AssistantResultPayload {
    public let success: Bool
    public let message: String?
    public let taskId: String?

    init(from value: Any?) {
        let map = value as? [String: Any] ?? [:]
        self.success = map["success"] as? Bool ?? false
        self.message = map["message"] as? String
        self.taskId = map["taskId"] as? String
    }
}

/// Decoded task returned by the Dart query handler.
public struct AssistantTaskPayload {
    public let id: String
    public let title: String
    public let dueDate: Date?
    public let isCompleted: Bool

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
/// Public so host apps can declare their own custom `AppIntent`s (with
/// their own Siri phrases) that call [performAction] — App Intents metadata
/// is compiled statically, so the intent *types* must live in Swift, while
/// all fulfillment logic stays in Dart.
///
/// Cold start: when Siri launches the app in the background to run an
/// intent, the bridge waits up to `handlerTimeout` for Dart to register its
/// handlers; past that, the intent fails with a friendly "open the app
/// first" dialog.
public final class AssistantIntentBridge {

    public static let shared = AssistantIntentBridge()

    /// ISO-8601 with fractional seconds first, plain fallback — matches
    /// Dart's `DateTime.toIso8601String()` output.
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let handlerTimeout: TimeInterval = 5.0
    private static let pollInterval: UInt64 = 100_000_000 // 100 ms
    /// Hard cap on a single Dart round-trip. A handler that never replies
    /// (bug in the host app) must not hang the intent until the system
    /// kills it — the assistant should get a spoken failure instead.
    private static let dartReplyTimeout: TimeInterval = 10.0

    private let stateQueue = DispatchQueue(
        label: "tech.ravenlab.flutter_assistant_intents.bridge"
    )
    private var channel: FlutterMethodChannel?
    private var handlersRegistered = false

    private var headlessEntrypoint = "main"
    private var registrant: ((FlutterEngine) -> Void)?
    private var headlessEngine: FlutterEngine?
    private var headlessBootAttempted = false

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

    func configureHeadlessBoot(
        entrypoint: String,
        registrant: @escaping (FlutterEngine) -> Void
    ) {
        stateQueue.sync {
            self.headlessEntrypoint = entrypoint
            self.registrant = registrant
        }
    }

    /// Boots a headless Flutter engine when an intent arrives in a process
    /// with no engine (cold start). Requires the host to have called
    /// `FlutterAssistantIntentsPlugin.setPluginRegistrantCallback`; a no-op
    /// otherwise, and attempted at most once per process.
    private func bootHeadlessEngineIfNeeded() async {
        let boot: ((FlutterEngine) -> Void)? = stateQueue.sync {
            guard channel == nil,
                  !headlessBootAttempted,
                  let registrant = registrant
            else { return nil }
            headlessBootAttempted = true
            return registrant
        }
        guard let boot = boot else { return }
        let entrypoint = stateQueue.sync { headlessEntrypoint }
        await MainActor.run {
            let engine = FlutterEngine(
                name: "flutter_assistant_intents_headless",
                project: nil,
                allowHeadlessExecution: true
            )
            guard engine.run(withEntrypoint: entrypoint) else { return }
            boot(engine)
            stateQueue.sync { self.headlessEngine = engine }
        }
    }

    // MARK: - Intent entry points

    /// Runs the app-defined action registered in Dart under [id].
    ///
    /// Use this from custom `AppIntent`s declared in the host's Runner
    /// target — the intent supplies the Siri phrases/UI, Dart supplies the
    /// logic:
    ///
    /// ```swift
    /// public func perform() async throws -> some IntentResult & ProvidesDialog {
    ///     let result = try await AssistantIntentBridge.shared.performAction(
    ///         id: "order_coffee",
    ///         parameters: ["size": size]
    ///     )
    ///     return .result(dialog: IntentDialog(
    ///         stringLiteral: result.message ?? (result.success ? "Done." : "Sorry, that failed.")
    ///     ))
    /// }
    /// ```
    ///
    /// `parameters` values must be method-channel-safe types (String, num,
    /// Bool, lists/maps of those).
    public func performAction(
        id: String,
        parameters: [String: Any] = [:]
    ) async throws -> AssistantResultPayload {
        let response = try await invokeDart(
            method: "intent.performAction",
            arguments: ["action": id, "parameters": parameters]
        )
        return AssistantResultPayload(from: response)
    }

    public func performAddTask(title: String, dueDate: Date?, notes: String?) async throws
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

    public func performCompleteTask(title: String) async throws -> AssistantResultPayload {
        let response = try await invokeDart(
            method: "intent.completeTask",
            arguments: ["title": title]
        )
        return AssistantResultPayload(from: response)
    }

    public func performQueryTasks(filter: String) async throws -> [AssistantTaskPayload] {
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
        await bootHeadlessEngineIfNeeded()
        guard await waitForHandlers(),
              let channel = stateQueue.sync(execute: { self.channel })
        else {
            throw AssistantBridgeError.appNotReady
        }
        let once = ResumeOnce()
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                channel.invokeMethod(method, arguments: arguments) { response in
                    guard once.tryClaim() else { return }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.dartReplyTimeout) {
                guard once.tryClaim() else { return }
                continuation.resume(throwing: AssistantBridgeError.appNotReady)
            }
        }
    }
}

/// Guarantees a `CheckedContinuation` is resumed exactly once when both a
/// reply callback and a timeout race for it.
private final class ResumeOnce {
    private let lock = NSLock()
    private var claimed = false

    func tryClaim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}

import Foundation

#if canImport(AppIntents)
import AppIntents
#endif

/// One option of a confirmation prompt requested by a Dart handler.
public struct AssistantChoicePayload {
    public let id: String
    public let title: String
    /// Raw style name from Dart: `normal`, `destructive` or `cancel`.
    public let style: String

    init?(from value: Any?) {
        guard let map = value as? [String: Any],
              let id = map["id"] as? String,
              let title = map["title"] as? String
        else { return nil }
        self.id = id
        self.title = title
        self.style = map["style"] as? String ?? "normal"
    }
}

/// A confirmation a Dart handler asked for before committing.
public struct AssistantConfirmationPayload {
    public let dialog: String
    public let options: [AssistantChoicePayload]

    init?(from value: Any?) {
        guard let map = value as? [String: Any],
              let dialog = map["dialog"] as? String,
              let rawOptions = map["options"] as? [Any]
        else { return nil }
        let options = rawOptions.compactMap { AssistantChoicePayload(from: $0) }
        if options.isEmpty { return nil }
        self.dialog = dialog
        self.options = options
    }
}

/// An intent that can put a confirmation prompt in front of the user.
///
/// `AssistantIntentBridge` stays free of App Intents types by talking to this
/// protocol instead: intents adopt it, the bridge calls it when a Dart
/// handler answers with a pending confirmation.
///
/// Every `AppIntent` gets the implementation for free on iOS 26 and later
/// through the extension below, so host apps that declare their own intents
/// only need to add the conformance and pass `confirming: self` to the
/// bridge:
///
/// ```swift
/// struct ClearCompletedIntent: AppIntent, AppIntentConfirming {
///     func perform() async throws -> some IntentResult & ProvidesDialog {
///         let payload = try await AssistantIntentBridge.shared.performAction(
///             id: "clear_completed",
///             confirming: self
///         )
///         return .result(dialog: IntentDialog(stringLiteral: payload.message ?? ""))
///     }
/// }
/// ```
public protocol AppIntentConfirming {
    /// Presents [confirmation] and returns the id of the option the user
    /// picked, or nil when no prompt could be shown.
    ///
    /// Returning nil is not an error: it means the system cannot ask, so the
    /// caller must treat the action as unconfirmed.
    func requestAssistantChoice(
        _ confirmation: AssistantConfirmationPayload
    ) async throws -> String?
}

#if canImport(AppIntents)

@available(iOS 26.0, macOS 26.0, watchOS 26.0, tvOS 26.0, *)
extension IntentChoiceOption.Style {
    /// Maps a style name sent from Dart onto the system style.
    ///
    /// Unknown names fall back to `.default`, so a newer Dart side never
    /// breaks an older host binary.
    static func fromWireValue(_ value: String) -> IntentChoiceOption.Style {
        switch value {
        case "destructive":
            return .destructive
        case "cancel":
            return .cancel
        default:
            return .default
        }
    }
}

extension AppIntentConfirming where Self: AppIntent {
    /// Shows the prompt with `requestChoice`, which needs iOS 26.
    ///
    /// On older systems there is no way to ask mid-intent, so this returns
    /// nil and the bridge reports the action as unperformed.
    public func requestAssistantChoice(
        _ confirmation: AssistantConfirmationPayload
    ) async throws -> String? {
        guard #available(iOS 26.0, macOS 26.0, watchOS 26.0, tvOS 26.0, *) else {
            return nil
        }
        let options = confirmation.options.map { option in
            IntentChoiceOption(
                title: LocalizedStringResource(stringLiteral: option.title),
                style: .fromWireValue(option.style)
            )
        }
        let picked = try await requestChoice(
            between: options,
            dialog: IntentDialog(stringLiteral: confirmation.dialog)
        )
        // requestChoice hands back the option, not its index, so the id is
        // recovered by matching on the title the option was built from.
        let index = options.firstIndex(of: picked)
        guard let index = index else { return nil }
        return confirmation.options[index].id
    }
}

#endif

#if canImport(AppIntents)
import AppIntents
import Foundation

/// Donates the built-in intents when the user performed the same action in
/// the app's own UI, so Siri Suggestions, Spotlight and the Lock Screen can
/// suggest it later. Arguments use the Dart `donations.*` wire format.
@available(iOS 16.0, *)
enum AssistantDonations {

    static func donateAddTask(_ arguments: [String: Any]) async throws {
        var intent = AddTaskIntent()
        intent.taskTitle = try requiredTitle(arguments)
        intent.dueDate = (arguments["dueDate"] as? String)
            .flatMap { AssistantIntentBridge.iso8601.date(from: $0) }
        intent.notes = arguments["notes"] as? String
        try await IntentDonationManager.shared.donate(intent: intent)
    }

    static func donateCompleteTask(_ arguments: [String: Any]) async throws {
        var intent = CompleteTaskIntent()
        intent.taskTitle = try requiredTitle(arguments)
        try await IntentDonationManager.shared.donate(intent: intent)
    }

    static func donateQueryTasks(_ arguments: [String: Any]) async throws {
        var intent = QueryTasksIntent()
        intent.filter = (arguments["filter"] as? String)
            .flatMap(AssistantTaskFilter.init(rawValue:)) ?? .today
        try await IntentDonationManager.shared.donate(intent: intent)
    }

    private static func requiredTitle(_ arguments: [String: Any]) throws -> String {
        guard let title = arguments["title"] as? String, !title.isEmpty else {
            throw AssistantDonationError.missingTitle
        }
        return title
    }
}

enum AssistantDonationError: Error, LocalizedError {
    case missingTitle

    var errorDescription: String? {
        switch self {
        case .missingTitle:
            return "A task donation needs a non-empty title."
        }
    }
}
#endif

import Foundation
import WiroKit

extension WiroError {
    /// User-facing message for the example app.
    var friendlyMessage: String {
        switch self {
        case .apiResult(let message, _, _, _):
            return "The API declined the request: \(message)"
        case .authentication:
            return "Authentication failed. Check your API key, secret, or proxy headers."
        case .validation(let message, _, _):
            return "Invalid request: \(message)"
        case .rateLimited(_, _, let retryAfter, _):
            if let retryAfter {
                return "Rate limited. Try again in \(Int(retryAfter))s."
            }
            return "Rate limited. Please wait and try again."
        case .unknownAPI(let message, let statusCode, _):
            return "Unexpected API response (\(statusCode)): \(message)"
        case .schemaValidation(let messages):
            if messages.isEmpty {
                return "Schema validation failed."
            }
            return "Schema validation failed: \(messages.joined(separator: "; "))"
        case .network(let message, _):
            return "Network error: \(message)"
        case .webSocket(let message, _):
            return "WebSocket error: \(message)"
        case .timedOut(let message, _):
            return message
        case .cancelled:
            return "Generation was cancelled."
        }
    }
}

extension Error {
    var friendlyMessage: String {
        if let wiro = self as? WiroError {
            return wiro.friendlyMessage
        }
        return localizedDescription
    }
}

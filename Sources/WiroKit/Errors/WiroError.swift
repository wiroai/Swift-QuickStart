import Foundation

/// Errors thrown by WiroKit.
///
/// Descriptions contain only human-readable messages and never include
/// credentials, signatures, headers, or request bodies.
public enum WiroError: Error, Sendable, Equatable {
    /// A 2xx response whose body contains `"result": false`.
    case apiResult(
        message: String,
        code: String?,
        statusCode: Int,
        responseBody: String?
    )

    /// An HTTP 401 or 403 authentication failure.
    case authentication(
        message: String,
        statusCode: Int,
        responseBody: String?
    )

    /// An HTTP 400 or 422 validation failure, or a local precondition
    /// failure (for example an invalid model slug).
    case validation(
        message: String,
        statusCode: Int,
        responseBody: String?
    )

    /// An HTTP 429 rate-limit response.
    case rateLimited(
        message: String,
        statusCode: Int,
        retryAfter: TimeInterval?,
        responseBody: String?
    )

    /// Any other non-2xx response, invalid JSON envelope, or unexpected
    /// API shape.
    case unknownAPI(
        message: String,
        statusCode: Int,
        responseBody: String?
    )

    /// Local schema validation failures from `WiroModelSchema.validate`.
    case schemaValidation(messages: [String])

    /// A transport-level network failure.
    case network(message: String, underlying: String?)

    /// A WebSocket failure.
    case webSocket(message: String, underlying: String?)

    /// A deadline was exceeded before a terminal result arrived.
    case timedOut(message: String, timeout: Duration)

    /// The surrounding Swift `Task` was cancelled.
    case cancelled
}

extension WiroError: LocalizedError {
    /// A human-readable description of the error.
    ///
    /// Never includes credentials or request bodies.
    public var errorDescription: String? {
        switch self {
        case .apiResult(let message, _, _, _):
            return message
        case .authentication(let message, _, _):
            return message
        case .validation(let message, _, _):
            return message
        case .rateLimited(let message, _, _, _):
            return message
        case .unknownAPI(let message, _, _):
            return message
        case .schemaValidation(let messages):
            if messages.isEmpty {
                return "Schema validation failed."
            }
            return messages.joined(separator: "; ")
        case .network(let message, _):
            return message
        case .webSocket(let message, _):
            return message
        case .timedOut(let message, _):
            return message
        case .cancelled:
            return "The operation was cancelled."
        }
    }
}

import Foundation

/// Severity of a `WiroLogEvent`.
public enum WiroLogLevel: String, Sendable, Equatable, Comparable {
    /// Verbose diagnostics for request lifecycle details.
    case debug
    /// Successful request completions and routine milestones.
    case info
    /// Recoverable issues such as retries.
    case warning
    /// Permanent failures that end an operation.
    case error

    private var rank: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        }
    }

    /// Compares severity ranks (`debug` < `info` < `warning` < `error`).
    public static func < (lhs: WiroLogLevel, rhs: WiroLogLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// A structured log event emitted by `WiroClient`.
///
/// Messages never contain credentials, signatures, headers, or bodies.
public struct WiroLogEvent: Sendable, Equatable {
    /// Event severity.
    public var level: WiroLogLevel
    /// Human-readable message (safe to display).
    public var message: String
    /// HTTP method when applicable.
    public var method: String?
    /// Request URL when applicable (may omit query).
    public var url: String?
    /// HTTP status code when applicable.
    public var statusCode: Int?
    /// Wall-clock duration of the attempt when applicable.
    public var duration: Duration?
    /// Zero-based retry count for this attempt when applicable.
    public var retryCount: Int?
    /// Safe error description when applicable.
    public var error: String?

    /// Creates a log event.
    public init(
        level: WiroLogLevel,
        message: String,
        method: String? = nil,
        url: String? = nil,
        statusCode: Int? = nil,
        duration: Duration? = nil,
        retryCount: Int? = nil,
        error: String? = nil
    ) {
        self.level = level
        self.message = message
        self.method = method
        self.url = url
        self.statusCode = statusCode
        self.duration = duration
        self.retryCount = retryCount
        self.error = error
    }
}

/// A Sendable closure that receives `WiroLogEvent` values from the client.
public typealias WiroLogger = @Sendable (WiroLogEvent) -> Void

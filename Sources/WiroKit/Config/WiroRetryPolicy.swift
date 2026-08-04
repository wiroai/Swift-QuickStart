import Foundation

/// Exponential backoff policy used by `WiroClient` for transient failures.
public struct WiroRetryPolicy: Sendable, Equatable {
    /// Maximum number of retries after the initial attempt.
    public var maxRetries: Int

    /// Delay before the first retry (before jitter).
    public var initialDelay: Duration

    /// Upper bound on the computed delay (before jitter).
    public var maximumDelay: Duration

    /// Multiplier applied for each subsequent retry index.
    public var multiplier: Double

    /// HTTP status codes that trigger a retry.
    public var retryableStatusCodes: Set<Int>

    /// Default policy: 2 retries, 500 ms → 4 s, ×2.0, for statuses
    /// `{408, 429, 500, 502, 503, 504}`.
    public static let `default` = WiroRetryPolicy(
        maxRetries: 2,
        initialDelay: .milliseconds(500),
        maximumDelay: .seconds(4),
        multiplier: 2.0,
        retryableStatusCodes: [408, 429, 500, 502, 503, 504]
    )

    /// A policy that never retries.
    public static let none = WiroRetryPolicy(
        maxRetries: 0,
        initialDelay: .zero,
        maximumDelay: .zero,
        multiplier: 1.0,
        retryableStatusCodes: []
    )

    /// Creates a retry policy.
    public init(
        maxRetries: Int,
        initialDelay: Duration,
        maximumDelay: Duration,
        multiplier: Double,
        retryableStatusCodes: Set<Int>
    ) {
        self.maxRetries = maxRetries
        self.initialDelay = initialDelay
        self.maximumDelay = maximumDelay
        self.multiplier = multiplier
        self.retryableStatusCodes = retryableStatusCodes
    }

    /// Computes the backoff delay for a retry attempt.
    ///
    /// The base delay is `initialDelay * multiplier^retryIndex`, capped at
    /// `maximumDelay`, then multiplied by a uniform jitter factor in
    /// `[0.8, 1.2]` drawn from `generator`.
    ///
    /// - Parameters:
    ///   - retryIndex: Zero-based index of the retry (0 = first retry).
    ///   - generator: Injectable random source for deterministic tests.
    /// - Returns: The jittered delay to sleep before the next attempt.
    public func delay<G: RandomNumberGenerator>(
        forRetryIndex retryIndex: Int,
        using generator: inout G
    ) -> Duration {
        let jitter = 0.8 + Double.random(in: 0..<0.4, using: &generator)
        return delay(forRetryIndex: retryIndex, jitterFactor: jitter)
    }

    /// Computes the backoff delay using an explicit jitter factor.
    ///
    /// - Parameters:
    ///   - retryIndex: Zero-based index of the retry (0 = first retry).
    ///   - jitterFactor: Multiplier, clamped to `[0.8, 1.2]`.
    /// - Returns: The jittered delay to sleep before the next attempt.
    public func delay(
        forRetryIndex retryIndex: Int,
        jitterFactor: Double
    ) -> Duration {
        let baseNanos =
            Self.nanoseconds(initialDelay)
            * pow(multiplier, Double(max(retryIndex, 0)))
        let capped = min(baseNanos, Self.nanoseconds(maximumDelay))
        let jitter = min(1.2, max(0.8, jitterFactor))
        let jittered = max(0, capped * jitter)
        return .nanoseconds(Int64(jittered.rounded()))
    }

    /// Whether `statusCode` is eligible for retry under this policy.
    public func shouldRetry(statusCode: Int) -> Bool {
        retryableStatusCodes.contains(statusCode)
    }

    private static func nanoseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000_000_000
            + Double(components.attoseconds) / 1_000_000_000
    }
}

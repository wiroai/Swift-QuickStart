import Foundation

/// A non-empty task access token returned as `socketaccesstoken` from a
/// run response.
///
/// Server-derived values use the failable initializer; an empty or
/// whitespace-only string yields `nil`.
public struct WiroTaskToken: Sendable, Hashable, Codable,
    RawRepresentable, CustomStringConvertible
{
    /// The underlying token string.
    public let rawValue: String

    public var description: String { rawValue }

    /// Creates a token from a non-empty string.
    ///
    /// - Parameter rawValue: The token string. Leading and trailing
    ///   whitespace is trimmed; empty results yield `nil`.
    public init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return nil }
        self.rawValue = trimmed
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let token = WiroTaskToken(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "WiroTaskToken must be non-empty."
            )
        }
        self = token
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

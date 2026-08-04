import Foundation

/// A non-empty task identifier returned as `taskid` / `id` from the API.
///
/// Server-derived values use the failable initializer; an empty or
/// whitespace-only string yields `nil`.
public struct WiroTaskID: Sendable, Hashable, Codable,
    RawRepresentable, CustomStringConvertible
{
    /// The underlying task id string.
    public let rawValue: String

    /// The raw task id string.
    public var description: String { rawValue }

    /// Creates a task id from a non-empty string.
    ///
    /// - Parameter rawValue: The id string. Leading and trailing
    ///   whitespace is trimmed; empty results yield `nil`.
    public init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return nil }
        self.rawValue = trimmed
    }

    /// Decodes from a single JSON string.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let id = WiroTaskID(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "WiroTaskID must be non-empty."
            )
        }
        self = id
    }

    /// Encodes as a single JSON string.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

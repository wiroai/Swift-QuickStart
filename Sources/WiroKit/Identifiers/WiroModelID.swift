import Foundation

/// A validated `owner/project` model identifier used by the Wiro API.
///
/// Both path segments must match `^[A-Za-z0-9][A-Za-z0-9._-]*$`.
/// Caller-supplied values are validated strictly (throwing); server-
/// derived values should use the failable `init?(parsing:)`.
public struct WiroModelID: Sendable, Hashable, Codable,
    CustomStringConvertible
{
    /// The model owner slug (for example `"openai"`).
    public let owner: String

    /// The model project slug (for example `"gpt-image-2"`).
    public let project: String

    /// The combined `owner/project` slug.
    public var slug: String { "\(owner)/\(project)" }

    public var description: String { slug }

    /// Creates a model identifier from validated owner and project
    /// segments.
    ///
    /// - Parameters:
    ///   - owner: The owner slug.
    ///   - project: The project slug.
    /// - Throws: `WiroError.validation` when either segment is invalid.
    public init(owner: String, project: String) throws {
        try Self.validateSegment(owner, label: "owner")
        try Self.validateSegment(project, label: "project")
        self.owner = owner
        self.project = project
    }

    /// Creates a model identifier without re-validating catalog slugs.
    ///
    /// Used by typed request factories whose owner/project pairs are
    /// compile-time constants already known to match the segment rules.
    init(catalogOwner owner: String, project: String) {
        self.owner = owner
        self.project = project
    }

    /// Parses a model identifier from an `"owner/project"` string.
    ///
    /// - Parameter parsing: A slash-separated owner/project string.
    /// - Returns: A valid identifier, or `nil` when the string is
    ///   missing, malformed, or contains invalid segments.
    public init?(parsing: String) {
        let trimmed = parsing.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        guard parts.count == 2 else { return nil }

        let owner = String(parts[0])
        let project = String(parts[1])
        guard Self.isValidSegment(owner),
              Self.isValidSegment(project)
        else {
            return nil
        }
        self.owner = owner
        self.project = project
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let parsed = WiroModelID(parsing: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription:
                    "Invalid WiroModelID string '\(raw)'."
            )
        }
        self = parsed
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(slug)
    }

    // MARK: - Validation

    private static func isValidSegment(_ value: String) -> Bool {
        // ^[A-Za-z0-9][A-Za-z0-9._-]*$
        guard let first = value.unicodeScalars.first,
              isASCIIAlphanumeric(first)
        else {
            return false
        }
        return value.unicodeScalars.dropFirst().allSatisfy { scalar in
            isASCIIAlphanumeric(scalar)
                || scalar == "."
                || scalar == "_"
                || scalar == "-"
        }
    }

    private static func isASCIIAlphanumeric(
        _ scalar: Unicode.Scalar
    ) -> Bool {
        (scalar >= "0" && scalar <= "9")
            || (scalar >= "A" && scalar <= "Z")
            || (scalar >= "a" && scalar <= "z")
    }

    private static func validateSegment(
        _ value: String,
        label: String
    ) throws {
        guard isValidSegment(value) else {
            throw WiroError.validation(
                message:
                    "Invalid model \(label) '\(value)'. "
                    + "Expected a slug matching "
                    + "^[A-Za-z0-9][A-Za-z0-9._-]*$.",
                statusCode: 0,
                responseBody: nil
            )
        }
    }
}

import Foundation

/// A typed model invocation that knows its target model and parameters.
public protocol WiroModelRequest: Sendable {
    /// The model this request targets.
    var model: WiroModelID { get }

    /// Wire parameters for `/Run`, including unresolved file inputs.
    func parameters() -> WiroJSON
}

/// A dynamic request for any `owner/project` model without a typed factory.
///
/// Prefer ``Wiro/model(_:parameters:)`` to construct instances:
///
/// ```swift
/// let request = try Wiro.model(
///     "owner/project",
///     parameters: ["prompt": "hello"]
/// )
/// let run = try await client.run(request)
/// ```
public struct WiroDynamicRequest: WiroModelRequest, Sendable, Equatable {
    /// Target model identifier (`owner/project`).
    public let model: WiroModelID
    /// Raw parameter map returned by ``parameters()``.
    public let parametersMap: WiroJSON

    /// Creates a dynamic request for `model`.
    ///
    /// - Parameters:
    ///   - model: Target model identifier.
    ///   - parameters: Wire parameters for `/Run`.
    public init(model: WiroModelID, parameters: WiroJSON) {
        self.model = model
        self.parametersMap = parameters
    }

    /// Builds the wire JSON dictionary for `/Run`.
    public func parameters() -> WiroJSON { parametersMap }
}

enum WiroRequestEncoding {
    static func files(_ files: [WiroFileInput]?) -> WiroJSONValue? {
        guard let files else { return nil }
        return .array(files.map(fileValue))
    }

    static func filesRequired(_ files: [WiroFileInput]) -> WiroJSONValue {
        .array(files.map(fileValue))
    }

    static func fileValue(_ file: WiroFileInput) -> WiroJSONValue {
        switch file {
        case .url(let url):
            return .string(url.absoluteString)
        case .data:
            return .fileInput(file)
        }
    }

    static func stringBool(_ value: Bool) -> WiroJSONValue {
        .string(value ? "true" : "false")
    }

    static func stringInt(_ value: Int) -> WiroJSONValue {
        .string(String(value))
    }

    static func onOff(_ value: Bool) -> WiroJSONValue {
        .string(value ? "on" : "off")
    }
}

enum WiroRequestValidation {
    static func fail(_ message: String) throws -> Never {
        throw WiroError.validation(
            message: message,
            statusCode: 0,
            responseBody: nil
        )
    }

    static func requireNonEmpty(_ value: String, label: String) throws {
        guard !value.isEmpty else {
            try fail("\(label) cannot be empty.")
        }
    }

    static func requireMaxLength(
        _ value: String,
        max: Int,
        label: String
    ) throws {
        guard value.count <= max else {
            try fail("\(label) cannot exceed \(max) characters.")
        }
    }

    static func requireRange(
        _ value: Int,
        min: Int,
        max: Int,
        label: String
    ) throws {
        guard value >= min, value <= max else {
            try fail("\(label) must be between \(min) and \(max).")
        }
    }

    static func requireOptionalRange(
        _ value: Int?,
        min: Int,
        max: Int,
        label: String
    ) throws {
        guard let value else { return }
        try requireRange(value, min: min, max: max, label: label)
    }

    static func requireNonNegative(_ value: Int?, label: String) throws {
        guard let value else { return }
        guard value >= 0 else {
            try fail("\(label) cannot be negative.")
        }
    }

    static func requireFluxDimension(_ value: Int?, label: String) throws {
        guard let value else { return }
        let ok = value == 0
            || (value >= 64 && value <= 2048 && value % 16 == 0)
        guard ok else {
            try fail(
                "\(label) must be 0 or a multiple of 16 between 64 and 2048."
            )
        }
    }

    static func requireOneOf(
        _ value: Int,
        allowed: [Int],
        label: String
    ) throws {
        guard allowed.contains(value) else {
            let list = allowed.map(String.init).joined(separator: ", ")
            try fail("\(label) must be one of: \(list).")
        }
    }

    static func requireOptionalCount(
        _ files: [WiroFileInput]?,
        max: Int,
        label: String
    ) throws {
        guard let files else { return }
        guard files.count <= max else {
            try fail("\(label) cannot exceed \(max) references.")
        }
    }

    static func requireOptionalCountRange(
        _ files: [WiroFileInput]?,
        min: Int,
        max: Int,
        label: String
    ) throws {
        guard let files else { return }
        guard files.count >= min, files.count <= max else {
            try fail("\(label) must contain between \(min) and \(max) items.")
        }
    }

    static func model(_ owner: String, _ project: String) -> WiroModelID {
        WiroModelID(catalogOwner: owner, project: project)
    }
}

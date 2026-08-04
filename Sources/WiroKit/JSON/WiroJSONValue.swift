import Foundation

/// A dictionary of JSON values keyed by string, used throughout WiroKit
/// for request parameters and raw response payloads.
public typealias WiroJSON = [String: WiroJSONValue]

/// A Sendable JSON value that can represent any JSON document structure.
///
/// Use this type for model parameters and for retaining the full raw
/// server payload on parsed models. Literal construction is supported so
/// call sites can write natural dictionaries such as
/// `["prompt": "hello", "seed": 42, "flag": true]`.
///
/// ## File inputs
///
/// ``WiroJSONValue/fileInput(_:)`` embeds a ``WiroFileInput`` in
/// parameter trees so call sites stay ergonomic:
/// `["inputImage": [.fileInput(.data(bytes, fileName: "a.png"))]]`.
/// That case is **never** encoded to the wire — ``encode(to:)`` throws.
/// ``WiroClient/runModel(_:parameters:callbackURL:)`` resolves every
/// nested file input to a URL string before encoding.
public enum WiroJSONValue: Sendable, Equatable {
    /// A JSON string.
    case string(String)
    /// A JSON number stored as `Double`.
    case number(Double)
    /// A JSON boolean.
    case bool(Bool)
    /// A JSON object.
    case object(WiroJSON)
    /// A JSON array.
    case array([WiroJSONValue])
    /// A JSON null.
    case null
    /// A local or remote file input that must be resolved before encoding.
    case fileInput(WiroFileInput)

    /// The string value when this is a `.string`, otherwise `nil`.
    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    /// Extracts an integer coerced from a `.number` or a numeric `.string`,
    /// otherwise `nil`.
    public var intValue: Int? {
        switch self {
        case .number(let value):
            guard value.isFinite, value.rounded() == value else { return nil }
            return Int(value)
        case .string(let value):
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        case .bool, .object, .array, .null, .fileInput:
            return nil
        }
    }

    /// A double coerced from a `.number` or a numeric `.string`,
    /// otherwise `nil`.
    public var doubleValue: Double? {
        switch self {
        case .number(let value):
            return value
        case .string(let value):
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        case .bool, .object, .array, .null, .fileInput:
            return nil
        }
    }

    /// The boolean value when this is a `.bool`, otherwise `nil`.
    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    /// The object dictionary when this is a `.object`, otherwise `nil`.
    public var objectValue: WiroJSON? {
        if case .object(let value) = self { return value }
        return nil
    }

    /// The array when this is an `.array`, otherwise `nil`.
    public var arrayValue: [WiroJSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    /// Whether this value is `.null`.
    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    /// The file input when this is a `.fileInput`, otherwise `nil`.
    public var fileInputValue: WiroFileInput? {
        if case .fileInput(let value) = self { return value }
        return nil
    }

    /// Converts this value into a Foundation JSON object suitable for
    /// `JSONSerialization`.
    ///
    /// - Throws: `WiroError.validation` when a ``WiroJSONValue/fileInput(_:)``
    ///   remains unresolved.
    public func toAny() throws -> Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .object(let value):
            var object: [String: Any] = [:]
            object.reserveCapacity(value.count)
            for (key, nested) in value {
                object[key] = try nested.toAny()
            }
            return object
        case .array(let value):
            return try value.map { try $0.toAny() }
        case .null:
            return NSNull()
        case .fileInput:
            throw WiroError.validation(
                message:
                    "Cannot serialize an unresolved WiroFileInput; "
                    + "resolve file inputs before encoding.",
                statusCode: 0,
                responseBody: nil
            )
        }
    }

    /// Creates a `WiroJSONValue` from a Foundation JSON object produced by
    /// `JSONSerialization`.
    ///
    /// - Parameter any: A JSON-compatible Foundation value.
    /// - Returns: The corresponding `WiroJSONValue`, or `nil` if `any` is
    ///   not a supported JSON type.
    public static func fromAny(_ any: Any) -> WiroJSONValue? {
        switch any {
        case is NSNull:
            return .null
        case let value as String:
            return .string(value)
        case let value as NSNumber:
            // Bool bridges to NSNumber; distinguish via CoreFoundation.
            if CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID() {
                return .bool(value.boolValue)
            }
            return .number(value.doubleValue)
        case let value as [String: Any]:
            var object: WiroJSON = [:]
            object.reserveCapacity(value.count)
            for (key, nested) in value {
                guard let converted = fromAny(nested) else { return nil }
                object[key] = converted
            }
            return .object(object)
        case let value as [Any]:
            var array: [WiroJSONValue] = []
            array.reserveCapacity(value.count)
            for nested in value {
                guard let converted = fromAny(nested) else { return nil }
                array.append(converted)
            }
            return .array(array)
        default:
            return nil
        }
    }
}

extension WiroJSONValue: Codable {
    /// Decodes any JSON value from a single-value container.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(WiroJSON.self) {
            self = .object(value)
        } else if let value = try? container.decode([WiroJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value."
            )
        }
    }

    /// Encodes this value as JSON.
    ///
    /// - Throws: `EncodingError.invalidValue` when this is a
    ///   ``WiroJSONValue/fileInput(_:)``.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        case .fileInput:
            throw EncodingError.invalidValue(
                self,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription:
                        "WiroJSONValue.fileInput cannot be encoded. "
                        + "Resolve file inputs before sending a request."
                )
            )
        }
    }
}

extension WiroJSONValue: ExpressibleByStringLiteral {
    /// Creates a `.string` from a string literal.
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension WiroJSONValue: ExpressibleByIntegerLiteral {
    /// Creates a `.number` from an integer literal.
    public init(integerLiteral value: Int) {
        self = .number(Double(value))
    }
}

extension WiroJSONValue: ExpressibleByFloatLiteral {
    /// Creates a `.number` from a floating-point literal.
    public init(floatLiteral value: Double) {
        self = .number(value)
    }
}

extension WiroJSONValue: ExpressibleByBooleanLiteral {
    /// Creates a `.bool` from a boolean literal.
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension WiroJSONValue: ExpressibleByArrayLiteral {
    /// Creates an `.array` from an array literal.
    public init(arrayLiteral elements: WiroJSONValue...) {
        self = .array(elements)
    }
}

extension WiroJSONValue: ExpressibleByDictionaryLiteral {
    /// Creates an `.object` from a dictionary literal.
    public init(dictionaryLiteral elements: (String, WiroJSONValue)...) {
        var object: WiroJSON = [:]
        object.reserveCapacity(elements.count)
        for (key, value) in elements {
            object[key] = value
        }
        self = .object(object)
    }
}

extension WiroJSONValue: ExpressibleByNilLiteral {
    /// Creates `.null` from a `nil` literal.
    public init(nilLiteral: ()) {
        self = .null
    }
}

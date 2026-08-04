import Foundation

/// Lenient extraction helpers for server-provided JSON values.
///
/// Numbers may arrive as strings (`"42"`), booleans as `"true"` / `"1"`,
/// and nested objects as JSON-encoded strings. These helpers never throw
/// for type mismatches — they return `nil` or a safe fallback instead.
enum JSONReader {
    /// A handler invoked when a nested JSON string cannot be decoded.
    typealias MalformedJSONHandler = @Sendable (String) -> Void

    /// Extracts a string from `value`.
    ///
    /// - Accepts `.string`.
    /// - Coerces `.number` and `.bool` to their textual representations.
    static func string(_ value: WiroJSONValue?) -> String? {
        guard let value else { return nil }
        switch value {
        case .string(let string):
            return string
        case .number(let number):
            if number.rounded() == number, number.isFinite {
                return String(Int(number))
            }
            return String(number)
        case .bool(let bool):
            return bool ? "true" : "false"
        case .null, .object, .array:
            return nil
        }
    }

    /// Extracts a string for `key` from `object`.
    static func string(_ object: WiroJSON, _ key: String) -> String? {
        string(object[key])
    }

    /// Extracts an integer from `value`.
    ///
    /// Accepts numeric values and numeric strings such as `"42"`.
    static func integer(_ value: WiroJSONValue?) -> Int? {
        guard let value else { return nil }
        switch value {
        case .number(let number):
            guard number.isFinite, number.rounded() == number else {
                return nil
            }
            return Int(number)
        case .string(let string):
            let trimmed = string.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            return Int(trimmed)
        case .bool, .null, .object, .array:
            return nil
        }
    }

    /// Extracts an integer for `key` from `object`.
    static func integer(_ object: WiroJSON, _ key: String) -> Int? {
        integer(object[key])
    }

    /// Extracts a double from `value`.
    ///
    /// Accepts numeric values and numeric strings such as `"3.14"`.
    static func double(_ value: WiroJSONValue?) -> Double? {
        guard let value else { return nil }
        switch value {
        case .number(let number):
            return number.isFinite ? number : nil
        case .string(let string):
            let trimmed = string.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard let parsed = Double(trimmed), parsed.isFinite else {
                return nil
            }
            return parsed
        case .bool, .null, .object, .array:
            return nil
        }
    }

    /// Extracts a double for `key` from `object`.
    static func double(_ object: WiroJSON, _ key: String) -> Double? {
        double(object[key])
    }

    /// Extracts a boolean from `value`.
    ///
    /// Accepts booleans, the strings `"true"` / `"false"` / `"1"` / `"0"`
    /// (case-insensitive), and the numbers `1` / `0`.
    ///
    /// - Parameters:
    ///   - value: The JSON value to interpret.
    ///   - fallback: Returned when `value` is missing or cannot be
    ///     interpreted as a boolean.
    static func boolean(
        _ value: WiroJSONValue?,
        fallback: Bool? = nil
    ) -> Bool? {
        guard let value else { return fallback }
        switch value {
        case .bool(let bool):
            return bool
        case .string(let string):
            switch string
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            {
            case "true", "1":
                return true
            case "false", "0":
                return false
            default:
                return fallback
            }
        case .number(let number):
            if number == 1 { return true }
            if number == 0 { return false }
            return fallback
        case .null, .object, .array:
            return fallback
        }
    }

    /// Extracts a boolean for `key` from `object`.
    static func boolean(
        _ object: WiroJSON,
        _ key: String,
        fallback: Bool? = nil
    ) -> Bool? {
        boolean(object[key], fallback: fallback)
    }

    /// Extracts an array from `value`.
    static func list(_ value: WiroJSONValue?) -> [WiroJSONValue]? {
        value?.arrayValue
    }

    /// Extracts an array for `key` from `object`.
    static func list(
        _ object: WiroJSON,
        _ key: String
    ) -> [WiroJSONValue]? {
        list(object[key])
    }

    /// Extracts an object from `value`.
    ///
    /// Also accepts a JSON-encoded string. If that nested JSON is
    /// malformed, returns an empty object and reports the raw string
    /// through `onMalformedJSON` instead of throwing.
    static func map(
        _ value: WiroJSONValue?,
        onMalformedJSON: MalformedJSONHandler? = nil
    ) -> WiroJSON? {
        guard let value else { return nil }
        switch value {
        case .object(let object):
            return object
        case .string(let string):
            return decodeNestedObject(
                string,
                onMalformedJSON: onMalformedJSON
            )
        case .null, .bool, .number, .array:
            return nil
        }
    }

    /// Extracts an object for `key` from `object`.
    static func map(
        _ object: WiroJSON,
        _ key: String,
        onMalformedJSON: MalformedJSONHandler? = nil
    ) -> WiroJSON? {
        map(object[key], onMalformedJSON: onMalformedJSON)
    }

    /// Extracts a URL from `value`.
    ///
    /// Only string values are accepted — numeric coercion is intentionally
    /// not applied, because `URL(string:)` can succeed for short numeric
    /// strings that are not meaningful URLs.
    static func url(_ value: WiroJSONValue?) -> URL? {
        guard case .string(let raw)? = value else { return nil }
        let string = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !string.isEmpty else { return nil }
        return URL(string: string)
    }

    /// Extracts a URL for `key` from `object`.
    static func url(_ object: WiroJSON, _ key: String) -> URL? {
        url(object[key])
    }

    /// Parses a Unix timestamp (seconds or milliseconds) into a `Date`.
    static func date(_ value: WiroJSONValue?) -> Date? {
        if let number = double(value) {
            return date(fromTimestamp: number)
        }
        if let string = string(value)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            let number = Double(string)
        {
            return date(fromTimestamp: number)
        }
        return nil
    }

    /// Extracts a date for `key` from `object`.
    static func date(_ object: WiroJSON, _ key: String) -> Date? {
        date(object[key])
    }

    // MARK: - Private

    private static func decodeNestedObject(
        _ string: String,
        onMalformedJSON: MalformedJSONHandler?
    ) -> WiroJSON {
        let trimmed = string.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8)
        else {
            onMalformedJSON?(string)
            return [:]
        }

        do {
            let decoded = try JSONDecoder()
                .decode(WiroJSONValue.self, from: data)
            if case .object(let object) = decoded {
                return object
            }
            onMalformedJSON?(string)
            return [:]
        } catch {
            onMalformedJSON?(string)
            return [:]
        }
    }

    private static func date(fromTimestamp number: Double) -> Date? {
        guard number.isFinite else { return nil }
        // Heuristic: values larger than 10^12 are milliseconds.
        if abs(number) >= 1_000_000_000_000 {
            return Date(timeIntervalSince1970: number / 1000.0)
        }
        return Date(timeIntervalSince1970: number)
    }
}

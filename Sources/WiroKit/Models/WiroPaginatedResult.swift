import Foundation

/// An error included in a Wiro API response payload.
public struct WiroAPIError: Sendable, Equatable {
    /// Machine-readable error code, when provided.
    public let code: String?
    /// Human-readable error message.
    public let message: String

    /// Creates an API error.
    public init(code: String?, message: String) {
        self.code = code
        self.message = message
    }

    /// Parses an API error from a Wiro payload object.
    public static func parse(_ json: WiroJSON) -> WiroAPIError {
        parse(json, onMalformedJSON: nil)
    }

    static func parse(
        _ json: WiroJSON,
        onMalformedJSON: JSONReader.MalformedJSONHandler?
    ) -> WiroAPIError {
        let code = JSONReader.string(json, "code")
            ?? JSONReader.integer(json, "code").map(String.init)
        return WiroAPIError(
            code: code,
            message: JSONReader.string(json, "message")
                ?? "Unknown Wiro API error"
        )
    }

    /// Parses the common `errors` collection used by Wiro responses.
    public static func parseList(from value: WiroJSONValue?) -> [WiroAPIError] {
        parseList(from: value, onMalformedJSON: nil)
    }

    static func parseList(
        from value: WiroJSONValue?,
        onMalformedJSON: JSONReader.MalformedJSONHandler?
    ) -> [WiroAPIError] {
        JSONReader.objects(value, onMalformedJSON: onMalformedJSON)
            .map { parse($0, onMalformedJSON: onMalformedJSON) }
    }
}

/// A typed paginated response from Wiro.
public struct WiroPaginatedResult<Item: Sendable>: Sendable {
    /// Whether Wiro marked the request as successful.
    public let isSuccess: Bool
    /// Total number of available items.
    public let total: Int
    /// Items returned on this page.
    public let items: [Item]
    /// API errors returned with the response.
    public let errors: [WiroAPIError]
    /// Original API payload for forward-compatible access.
    public let raw: WiroJSON

    /// Creates a paginated result.
    public init(
        isSuccess: Bool,
        total: Int,
        items: [Item],
        errors: [WiroAPIError],
        raw: WiroJSON
    ) {
        self.isSuccess = isSuccess
        self.total = total
        self.items = items
        self.errors = errors
        self.raw = raw
    }

    /// Parses a paginated response using `itemFromJSON` for each item.
    public static func parse(
        _ json: WiroJSON,
        itemsKey: String,
        itemFromJSON: (WiroJSON) -> Item
    ) -> WiroPaginatedResult<Item> {
        parse(
            json,
            itemsKey: itemsKey,
            onMalformedJSON: nil,
            itemFromJSON: itemFromJSON
        )
    }

    static func parse(
        _ json: WiroJSON,
        itemsKey: String,
        onMalformedJSON: JSONReader.MalformedJSONHandler?,
        itemFromJSON: (WiroJSON) -> Item
    ) -> WiroPaginatedResult<Item> {
        let items = JSONReader.objects(
            json,
            itemsKey,
            onMalformedJSON: onMalformedJSON
        ).map(itemFromJSON)

        return WiroPaginatedResult(
            isSuccess: JSONReader.boolean(json, "result", fallback: false)
                ?? false,
            total: JSONReader.integer(json, "total") ?? items.count,
            items: items,
            errors: WiroAPIError.parseList(
                from: json["errors"],
                onMalformedJSON: onMalformedJSON
            ),
            raw: json
        )
    }
}

import Foundation

/// A curated group returned by the Explore API.
public struct WiroExploreCategory: Sendable, Equatable {
    /// Category identifier.
    public let id: String
    /// Display title.
    public let title: String
    /// Curated models in this category.
    public let models: [WiroModel]
    /// Total number of models in this category.
    public let total: Int
    /// Optional category URL.
    public let url: URL?
    /// Original API payload for forward-compatible access.
    public let raw: WiroJSON

    /// Creates an explore category.
    public init(
        id: String,
        title: String,
        models: [WiroModel],
        total: Int,
        url: URL? = nil,
        raw: WiroJSON
    ) {
        self.id = id
        self.title = title
        self.models = models
        self.total = total
        self.url = url
        self.raw = raw
    }

    /// Parses an explore category from a Wiro payload.
    public static func parse(_ json: WiroJSON) -> WiroExploreCategory {
        parse(json, onMalformedJSON: nil)
    }

    static func parse(
        _ json: WiroJSON,
        onMalformedJSON: JSONReader.MalformedJSONHandler?
    ) -> WiroExploreCategory {
        let models = JSONReader.objects(
            json,
            "tools",
            onMalformedJSON: onMalformedJSON
        ).map { WiroModel.parse($0, onMalformedJSON: onMalformedJSON) }

        return WiroExploreCategory(
            id: JSONReader.string(json, "id") ?? "",
            title: JSONReader.string(json, "title")
                ?? JSONReader.string(json, "name")
                ?? "",
            models: models,
            total: JSONReader.integer(json, "total") ?? models.count,
            url: JSONReader.url(json, "url"),
            raw: json
        )
    }
}

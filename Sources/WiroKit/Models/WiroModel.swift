import Foundation

/// Aggregate execution statistics for a model.
public struct WiroModelTaskStats: Sendable, Equatable {
    /// Total number of model runs.
    public let runCount: Int
    /// Number of successful runs.
    public let successCount: Int
    /// Number of failed runs.
    public let errorCount: Int
    /// Timestamp of the most recent run.
    public let lastRunTime: Date?

    /// Creates model task statistics.
    public init(
        runCount: Int,
        successCount: Int,
        errorCount: Int,
        lastRunTime: Date?
    ) {
        self.runCount = runCount
        self.successCount = successCount
        self.errorCount = errorCount
        self.lastRunTime = lastRunTime
    }

    /// Parses statistics from a Wiro API payload.
    public static func parse(_ json: WiroJSON) -> WiroModelTaskStats {
        WiroModelTaskStats(
            runCount: JSONReader.integer(json, "runcount") ?? 0,
            successCount: JSONReader.integer(json, "successcount") ?? 0,
            errorCount: JSONReader.integer(json, "errorcount") ?? 0,
            lastRunTime: JSONReader.date(json, "lastruntime")
        )
    }
}

/// A model available through Wiro.
public struct WiroModel: Sendable, Equatable {
    /// Stable model identifier.
    public let id: String
    /// Model owner slug.
    public let owner: String
    /// Model project slug.
    public let slug: String
    /// Display title.
    public let title: String?
    /// Human-readable model description.
    public let description: String?
    /// Search-optimized description.
    public let seoDescription: String?
    /// Model cover image.
    public let imageURL: URL?
    /// Categories assigned by Wiro.
    public let categories: [String]
    /// Search and discovery tags.
    public let tags: [String]
    /// Sample output URLs.
    public let samples: [String]
    /// Approximate processing time reported by Wiro.
    public let computingTime: String?
    /// Approximate cost reported by Wiro.
    public let approximateCost: String?
    /// Dynamic pricing descriptor.
    public let dynamicPrice: String?
    /// Cost-per-second descriptor.
    public let cps: String?
    /// Aggregate execution statistics.
    public let taskStats: WiroModelTaskStats?
    /// Original API payload for forward-compatible access.
    public let raw: WiroJSON

    /// Canonical `owner/project` identifier when both slugs are valid.
    public var modelID: WiroModelID? {
        WiroModelID(parsing: "\(owner)/\(slug)")
    }

    /// Creates a Wiro model.
    public init(
        id: String,
        owner: String,
        slug: String,
        title: String? = nil,
        description: String? = nil,
        seoDescription: String? = nil,
        imageURL: URL? = nil,
        categories: [String] = [],
        tags: [String] = [],
        samples: [String] = [],
        computingTime: String? = nil,
        approximateCost: String? = nil,
        dynamicPrice: String? = nil,
        cps: String? = nil,
        taskStats: WiroModelTaskStats? = nil,
        raw: WiroJSON
    ) {
        self.id = id
        self.owner = owner
        self.slug = slug
        self.title = title
        self.description = description
        self.seoDescription = seoDescription
        self.imageURL = imageURL
        self.categories = categories
        self.tags = tags
        self.samples = samples
        self.computingTime = computingTime
        self.approximateCost = approximateCost
        self.dynamicPrice = dynamicPrice
        self.cps = cps
        self.taskStats = taskStats
        self.raw = raw
    }

    /// Parses a model from a Wiro API payload.
    public static func parse(_ json: WiroJSON) -> WiroModel {
        parse(json, onMalformedJSON: nil)
    }

    static func parse(
        _ json: WiroJSON,
        onMalformedJSON: JSONReader.MalformedJSONHandler?
    ) -> WiroModel {
        let taskStatsJSON = JSONReader.map(
            json,
            "taskstat",
            onMalformedJSON: onMalformedJSON
        )
        return WiroModel(
            id: JSONReader.string(json, "id") ?? "",
            owner: JSONReader.string(json, "cleanslugowner")
                ?? JSONReader.string(json, "slugowner")
                ?? "",
            slug: JSONReader.string(json, "cleanslugproject")
                ?? JSONReader.string(json, "slugproject")
                ?? "",
            title: JSONReader.string(json, "title"),
            description: JSONReader.string(json, "description"),
            seoDescription: JSONReader.string(json, "seodescription"),
            imageURL: JSONReader.url(json, "image"),
            categories: JSONReader.stringList(json, "categories"),
            tags: JSONReader.stringList(json, "tags"),
            samples: JSONReader.stringList(json, "samples"),
            computingTime: JSONReader.string(json, "computingtime"),
            approximateCost: JSONReader.string(json, "approximatelycost"),
            dynamicPrice: JSONReader.string(json, "dynamicprice"),
            cps: JSONReader.string(json, "cps"),
            taskStats: taskStatsJSON.map(WiroModelTaskStats.parse),
            raw: json
        )
    }
}

import Foundation

extension WiroClient {
    /// Searches and lists models available on Wiro.
    ///
    /// - Parameters:
    ///   - search: Free-text search query.
    ///   - categories: Category filters.
    ///   - start: Zero-based offset (`>= 0`).
    ///   - limit: Page size (`1...100`).
    ///   - sort: Sort field (default `.relevance`).
    ///   - owner: Optional owner slug filter (`slugowner`).
    ///   - order: Optional sort direction.
    /// - Returns: A paginated list of models.
    /// - Throws: `WiroError.validation` when `start`/`limit` are out of
    ///   range, or transport/API errors from the request.
    public func searchModels(
        search: String = "",
        categories: [String] = [],
        start: Int = 0,
        limit: Int = 20,
        sort: WiroModelSort = .relevance,
        owner: String? = nil,
        order: WiroSortOrder? = nil
    ) async throws -> WiroPaginatedResult<WiroModel> {
        guard start >= 0 else {
            throw WiroError.validation(
                message: "start cannot be negative.",
                statusCode: 0,
                responseBody: nil
            )
        }
        guard (1...100).contains(limit) else {
            throw WiroError.validation(
                message: "limit must be between 1 and 100.",
                statusCode: 0,
                responseBody: nil
            )
        }

        var body: WiroJSON = [
            "start": .string(String(start)),
            "limit": .string(String(limit)),
            "search": .string(search),
            "categories": .array(categories.map { .string($0) }),
            "sort": .string(sort.apiValue),
            "hideworkflows": .bool(true),
            "summary": .bool(true),
        ]
        if let owner {
            body["slugowner"] = .string(owner)
        }
        if let order {
            body["order"] = .string(order.apiValue)
        }

        let handler = malformedJSONHandler()
        return try await post("/Tool/List", body: body) { json in
            WiroPaginatedResult.parse(
                json,
                itemsKey: "tool",
                onMalformedJSON: handler,
                itemFromJSON: {
                    WiroModel.parse($0, onMalformedJSON: handler)
                }
            )
        }
    }

    /// Returns curated model categories from `/Tool/Explore`.
    public func explore() async throws -> [WiroExploreCategory] {
        let handler = malformedJSONHandler()
        return try await post("/Tool/Explore", body: [:]) { json in
            JSONReader.objects(
                json,
                "explore",
                onMalformedJSON: handler
            ).map {
                WiroExploreCategory.parse($0, onMalformedJSON: handler)
            }
        }
    }

    /// Returns the input schema for `model` from `/Tool/Detail`.
    ///
    /// - Parameter model: The model to describe.
    /// - Throws: `WiroError.unknownAPI` when the `tool` array is missing
    ///   or empty.
    public func getModelSchema(
        _ model: WiroModelID
    ) async throws -> WiroModelSchema {
        let handler = malformedJSONHandler()
        return try await post(
            "/Tool/Detail",
            body: [
                "slugowner": .string(model.owner),
                "slugproject": .string(model.project),
            ]
        ) { json in
            let tools = JSONReader.objects(
                json,
                "tool",
                onMalformedJSON: handler
            )
            guard let first = tools.first else {
                throw WiroError.unknownAPI(
                    message:
                        "The model schema response did not contain a model.",
                    statusCode: 200,
                    responseBody: nil
                )
            }
            return WiroModelSchema.parse(
                first,
                onMalformedJSON: handler
            )
        }
    }
}

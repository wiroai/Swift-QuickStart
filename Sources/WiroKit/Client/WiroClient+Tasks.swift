import Foundation

extension WiroClient {
    /// Starts `model` with the supplied dynamic `parameters`.
    ///
    /// This billable operation is not retried automatically.
    ///
    /// ```swift
    /// let run = try await client.runModel(
    ///     WiroModelID(parsing: "owner/project")!,
    ///     parameters: ["prompt": "A mountain lake"]
    /// )
    /// let task = try await client.waitForTask(run.taskToken!)
    /// ```
    ///
    /// - Parameters:
    ///   - model: The model to run.
    ///   - parameters: Model input parameters.
    ///   - callbackURL: Optional HTTP(S) webhook URL notified on completion.
    /// - Returns: The immediate run acceptance payload.
    /// - Throws: `WiroError.validation` for an invalid callback URL, or
    ///   transport/API errors from the request.
    public func runModel(
        _ model: WiroModelID,
        parameters: WiroJSON = [:],
        callbackURL: URL? = nil
    ) async throws -> WiroRunResult {
        let callback = try callbackURL.map(Self.validateCallbackURL)
        var body = parameters
        if Self.containsFileInput(body) {
            body = try await resolveFileInputs(body)
        }
        if let callback {
            body["callbackUrl"] = .string(callback.absoluteString)
        }

        let owner = Self.percentEncodePathSegment(model.owner)
        let project = Self.percentEncodePathSegment(model.project)
        let path = "/Run/\(owner)/\(project)"
        let handler = malformedJSONHandler()

        return try await post(
            path,
            body: body,
            retryable: false
        ) { json in
            WiroRunResult.parse(json, onMalformedJSON: handler)
        }
    }

    /// Returns task details using a task access token.
    ///
    /// - Parameter token: Task access token from a run response.
    /// - Returns: The latest task snapshot.
    public func getTask(_ token: WiroTaskToken) async throws -> WiroTask {
        let handler = malformedJSONHandler()
        return try await post(
            "/Task/Detail",
            body: ["tasktoken": .string(token.rawValue)]
        ) { json in
            try Self.taskFromResponse(json, onMalformedJSON: handler)
        }
    }

    /// Returns task details using the server-side task id.
    ///
    /// - Parameter id: Server-assigned task identifier.
    /// - Returns: The latest task snapshot.
    public func getTaskByID(_ id: WiroTaskID) async throws -> WiroTask {
        let handler = malformedJSONHandler()
        return try await post(
            "/Task/Detail",
            body: ["taskid": .string(id.rawValue)]
        ) { json in
            try Self.taskFromResponse(json, onMalformedJSON: handler)
        }
    }

    /// Requests cancellation of a queued task.
    ///
    /// - Parameter id: Server-assigned task identifier from a run response.
    /// - Returns: `true` when the API accepted the cancel request.
    public func cancelTask(_ id: WiroTaskID) async throws -> Bool {
        try await post(
            "/Task/Cancel",
            body: ["taskid": .string(id.rawValue)]
        ) { json in
            JSONReader.boolean(json, "result", fallback: false) ?? false
        }
    }

    /// Stops a running task.
    ///
    /// - Parameter token: Task access token from a run response.
    /// - Returns: `true` when the API accepted the kill request.
    public func killTask(_ token: WiroTaskToken) async throws -> Bool {
        try await post(
            "/Task/Kill",
            body: ["socketaccesstoken": .string(token.rawValue)]
        ) { json in
            JSONReader.boolean(json, "result", fallback: false) ?? false
        }
    }

    /// Stops a running task using its server-side task id.
    ///
    /// - Parameter id: Server-assigned task identifier from a run response.
    /// - Returns: `true` when the API accepted the kill request.
    public func killTask(_ id: WiroTaskID) async throws -> Bool {
        try await post(
            "/Task/Kill",
            body: ["taskid": .string(id.rawValue)]
        ) { json in
            JSONReader.boolean(json, "result", fallback: false) ?? false
        }
    }

    // MARK: - Helpers

    static func taskFromResponse(
        _ json: WiroJSON,
        onMalformedJSON: JSONReader.MalformedJSONHandler?
    ) throws -> WiroTask {
        let tasks = JSONReader.objects(
            json,
            "tasklist",
            onMalformedJSON: onMalformedJSON
        )
        guard let first = tasks.first else {
            throw WiroError.unknownAPI(
                message: "The task response did not contain a task.",
                statusCode: 200,
                responseBody: nil
            )
        }
        return WiroTask.parse(first, onMalformedJSON: onMalformedJSON)
    }

    static func validateCallbackURL(_ url: URL) throws -> URL {
        let scheme = url.scheme?.lowercased()
        let hasHTTP = scheme == "http" || scheme == "https"
        let hasAuthority = url.host != nil && !(url.host?.isEmpty ?? true)
        let hasUserInfo = url.user != nil || url.password != nil
        let hasFragment = url.fragment != nil

        guard hasHTTP, hasAuthority, !hasUserInfo, !hasFragment else {
            throw WiroError.validation(
                message:
                    "callbackURL must be an HTTP(S) URL without credentials or a fragment.",
                statusCode: 0,
                responseBody: nil
            )
        }
        return url
    }

    /// Percent-encodes a single `/Run/{owner}/{project}` path segment.
    static func percentEncodePathSegment(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed)
            ?? value
    }
}

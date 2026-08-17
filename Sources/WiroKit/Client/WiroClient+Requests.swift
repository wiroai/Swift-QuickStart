import Foundation

extension WiroClient {
    /// Runs a typed model request without waiting for completion.
    ///
    /// ```swift
    /// let run = try await client.run(
    ///     Wiro.flux2Pro(prompt: "A mountain lake")
    /// )
    /// let task = try await client.waitForTask(run.taskToken!)
    /// ```
    ///
    /// - Parameters:
    ///   - request: A typed or dynamic model request.
    ///   - callbackURL: Optional completion webhook.
    /// - Returns: The immediate run response containing a task token.
    /// - Throws: `WiroError` for validation, auth, or transport failures.
    public func run(
        _ request: some WiroModelRequest,
        callbackURL: URL? = nil
    ) async throws -> WiroRunResult {
        try await runModel(
            request.model,
            parameters: request.parameters(),
            callbackURL: callbackURL
        )
    }

    /// Starts a typed model request, tracks it, and returns the result.
    ///
    /// ```swift
    /// let result = try await client.subscribe(
    ///     Wiro.flux2Pro(prompt: "A mountain lake", width: 1024),
    ///     trackingMode: .polling
    /// )
    /// if case .success(let task) = result {
    ///     print(task.outputs)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: A typed or dynamic model request.
    ///   - callbackURL: Optional completion webhook.
    ///   - timeout: Maximum tracking duration.
    ///   - trackingMode: Polling or WebSocket tracking.
    ///   - onUpdate: Optional callback for each tracking update.
    /// - Returns: A sealed success or failure result.
    /// - Throws: `WiroError` when the run or tracking fails.
    public func subscribe(
        _ request: some WiroModelRequest,
        callbackURL: URL? = nil,
        timeout: Duration = .seconds(600),
        trackingMode: WiroTaskTrackingMode = .polling,
        onUpdate: (@Sendable (WiroTaskUpdate) -> Void)? = nil
    ) async throws -> WiroTaskResult {
        try await subscribe(
            request.model,
            parameters: request.parameters(),
            callbackURL: callbackURL,
            timeout: timeout,
            trackingMode: trackingMode,
            onUpdate: onUpdate
        )
    }

    /// Starts a typed model request and streams tracking updates.
    ///
    /// ```swift
    /// for try await update in try await client.subscribeStream(
    ///     try Wiro.flux2Pro(prompt: "A mountain lake")
    /// ) {
    ///     print(update.status as Any)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - request: A typed or dynamic model request.
    ///   - callbackURL: Optional completion webhook.
    ///   - timeout: Maximum tracking duration.
    ///   - trackingMode: Polling or WebSocket tracking.
    /// - Returns: A stream of ``WiroTaskUpdate`` values until terminal.
    /// - Throws: `WiroError.validation` when `timeout` is not positive.
    public func subscribeStream(
        _ request: some WiroModelRequest,
        callbackURL: URL? = nil,
        timeout: Duration = .seconds(600),
        trackingMode: WiroTaskTrackingMode = .polling
    ) throws -> AsyncThrowingStream<WiroTaskUpdate, Error> {
        try subscribeStream(
            request.model,
            parameters: request.parameters(),
            callbackURL: callbackURL,
            timeout: timeout,
            trackingMode: trackingMode
        )
    }
}

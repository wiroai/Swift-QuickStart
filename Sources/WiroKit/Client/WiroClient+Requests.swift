import Foundation

extension WiroClient {
    /// Runs a typed model request.
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

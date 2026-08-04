import Foundation

extension WiroClient {
    /// Emits polled task snapshots until the task reaches a terminal status.
    ///
    /// Cancelling the consuming `Task` stops the polling loop and finishes
    /// the stream with ``WiroError/cancelled``.
    ///
    /// - Parameters:
    ///   - token: Task access token from a run response.
    ///   - timeout: Maximum time to wait (must be `> 0`).
    /// - Returns: A stream of task snapshots.
    /// - Throws: ``WiroError/validation`` when `timeout` is not positive.
    public func watchTask(
        _ token: WiroTaskToken,
        timeout: Duration = .seconds(600)
    ) throws -> AsyncThrowingStream<WiroTask, Error> {
        guard timeout > .zero else {
            throw WiroError.validation(
                message: "timeout must be greater than zero.",
                statusCode: 0,
                responseBody: nil
            )
        }

        let pollInterval = self.pollInterval
        let clock = self.clock
        let sleeper = self.sleeper

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    _ = try await self.pollTaskLoop(
                        token: token,
                        timeout: timeout,
                        pollInterval: pollInterval,
                        clock: clock,
                        sleeper: sleeper,
                        onTask: { task in
                            continuation.yield(task)
                        }
                    )
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: WiroError.cancelled)
                } catch let error as WiroError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    /// Polls until a task reaches a terminal status.
    public func waitForTask(
        _ token: WiroTaskToken,
        timeout: Duration = .seconds(600)
    ) async throws -> WiroTask {
        do {
            let stream = try watchTask(token, timeout: timeout)
            var last: WiroTask?
            for try await task in stream {
                last = task
                if task.status.isTerminal {
                    return task
                }
            }
            try checkCancellation()
            if let last, last.status.isTerminal {
                return last
            }
            throw WiroError.timedOut(
                message:
                    "Task did not finish within \(Self.timeoutDescription(timeout)).",
                timeout: timeout
            )
        } catch is CancellationError {
            throw WiroError.cancelled
        }
    }

    /// Starts `model`, tracks it, and returns a typed terminal result.
    ///
    /// - Parameters:
    ///   - model: Model to run.
    ///   - parameters: Model parameters (may include file inputs).
    ///   - callbackURL: Optional completion webhook.
    ///   - timeout: Tracking deadline (must be `> 0`).
    ///   - trackingMode: `.polling` in this step; `.webSocket` in Step 8.
    ///   - onUpdate: Optional callback for each tracking update.
    public func subscribe(
        _ model: WiroModelID,
        parameters: WiroJSON = [:],
        callbackURL: URL? = nil,
        timeout: Duration = .seconds(600),
        trackingMode: WiroTaskTrackingMode = .polling,
        onUpdate: (@Sendable (WiroTaskUpdate) -> Void)? = nil
    ) async throws -> WiroTaskResult {
        let task = try await subscribeTask(
            model,
            parameters: parameters,
            callbackURL: callbackURL,
            timeout: timeout,
            trackingMode: trackingMode,
            onUpdate: onUpdate
        )
        return WiroTaskResult.from(task: task)
    }

    /// Starts `model` and streams typed updates until tracking completes.
    ///
    /// Cancelling the stream consumer stops tracking.
    public func subscribeStream(
        _ model: WiroModelID,
        parameters: WiroJSON = [:],
        callbackURL: URL? = nil,
        timeout: Duration = .seconds(600),
        trackingMode: WiroTaskTrackingMode = .polling
    ) throws -> AsyncThrowingStream<WiroTaskUpdate, Error> {
        guard timeout > .zero else {
            throw WiroError.validation(
                message: "timeout must be greater than zero.",
                statusCode: 0,
                responseBody: nil
            )
        }

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    _ = try await self.subscribeTask(
                        model,
                        parameters: parameters,
                        callbackURL: callbackURL,
                        timeout: timeout,
                        trackingMode: trackingMode,
                        onUpdate: { update in
                            continuation.yield(update)
                        }
                    )
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: WiroError.cancelled)
                } catch let error as WiroError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    // MARK: - Internal tracking

    func subscribeTask(
        _ model: WiroModelID,
        parameters: WiroJSON,
        callbackURL: URL?,
        timeout: Duration,
        trackingMode: WiroTaskTrackingMode,
        onUpdate: (@Sendable (WiroTaskUpdate) -> Void)?
    ) async throws -> WiroTask {
        guard timeout > .zero else {
            throw WiroError.validation(
                message: "timeout must be greater than zero.",
                statusCode: 0,
                responseBody: nil
            )
        }

        let run = try await runModel(
            model,
            parameters: parameters,
            callbackURL: callbackURL
        )
        guard let taskToken = run.taskToken else {
            throw WiroError.unknownAPI(
                message:
                    "The model run response did not contain a task token.",
                statusCode: 200,
                responseBody: nil
            )
        }

        switch trackingMode {
        case .polling:
            return try await trackWithPolling(
                taskToken,
                timeout: timeout,
                onUpdate: onUpdate
            )
        case .webSocket:
            // STEP 8 INTEGRATION POINT: replace with watchTaskSocket +
            // polling fallback for the remaining timeout budget.
            throw WiroError.unknownAPI(
                message: "WebSocket tracking is not implemented yet.",
                statusCode: 0,
                responseBody: nil
            )
        }
    }

    func trackWithPolling(
        _ token: WiroTaskToken,
        timeout: Duration,
        onUpdate: (@Sendable (WiroTaskUpdate) -> Void)?
    ) async throws -> WiroTask {
        try await pollTaskLoop(
            token: token,
            timeout: timeout,
            pollInterval: pollInterval,
            clock: clock,
            sleeper: sleeper,
            onTask: { task in
                onUpdate?(.snapshot(task))
            }
        )
    }

    /// Polls `/Task/Detail` until a terminal status or timeout.
    ///
    /// - Returns: The terminal task snapshot.
    func pollTaskLoop(
        token: WiroTaskToken,
        timeout: Duration,
        pollInterval: Duration,
        clock: @escaping WiroClock,
        sleeper: @escaping WiroSleeper,
        onTask: @Sendable (WiroTask) -> Void
    ) async throws -> WiroTask {
        let deadline = clock().addingTimeInterval(
            durationToTimeInterval(timeout)
        )

        while clock() < deadline {
            try checkCancellation()
            let task = try await getTask(token)
            onTask(task)
            if task.status.isTerminal {
                return task
            }

            try checkCancellation()
            let remaining = deadline.timeIntervalSince(clock())
            guard remaining > 0 else { break }

            let pollSeconds = durationToTimeInterval(pollInterval)
            let sleepSeconds = min(remaining, pollSeconds)
            do {
                try await sleeper(.seconds(sleepSeconds))
            } catch is CancellationError {
                throw WiroError.cancelled
            }
            try checkCancellation()
        }

        throw WiroError.timedOut(
            message:
                "Task did not finish within \(Self.timeoutDescription(timeout)).",
            timeout: timeout
        )
    }

    static func timeoutDescription(_ timeout: Duration) -> String {
        let seconds = timeout.components.seconds
        if timeout.components.attoseconds == 0 {
            return "\(seconds) seconds"
        }
        let total =
            Double(seconds)
            + Double(timeout.components.attoseconds)
            / 1_000_000_000_000_000_000
        return "\(total) seconds"
    }
}

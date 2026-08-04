import Foundation
import Testing
@testable import WiroKit

@Suite("Task tracking (polling)")
struct TrackingTests {
    @Test("watchTask yields queued -> running -> completed")
    func watchTaskStatusProgression() async throws {
        let token = try #require(WiroTaskToken(rawValue: "tok"))
        let clock = ControllableClock()
        let transport = MockHTTPTransport(handlers: [
            { _ in taskDetailResponse(status: "task_queue") },
            { _ in taskDetailResponse(status: "task_start") },
            { _ in taskDetailResponse(
                status: "task_postprocess_end",
                pexit: 0
            ) },
        ])
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            pollInterval: .seconds(3),
            clock: clock.clock,
            sleeper: clock.sleeper
        )

        var statuses: [WiroTaskStatus] = []
        for try await task in try await client.watchTask(
            token,
            timeout: .seconds(60)
        ) {
            statuses.append(task.status)
        }

        #expect(statuses == [.queued, .running, .completed])
        #expect(clock.sleepDurations == [.seconds(3), .seconds(3)])
        #expect(await transport.requestCount == 3)
    }

    @Test("waitForTask returns the terminal snapshot")
    func waitForTaskTerminal() async throws {
        let token = try #require(WiroTaskToken(rawValue: "tok"))
        let clock = ControllableClock()
        let transport = MockHTTPTransport(handlers: [
            { _ in taskDetailResponse(status: "task_start") },
            { _ in taskDetailResponse(
                status: "task_postprocess_end",
                pexit: 0
            ) },
        ])
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            pollInterval: .milliseconds(500),
            clock: clock.clock,
            sleeper: clock.sleeper
        )

        let task = try await client.waitForTask(
            token,
            timeout: .seconds(30)
        )
        #expect(task.status == .completed)
        #expect(task.isSuccessful)
        #expect(clock.sleepDurations == [.milliseconds(500)])
    }

    @Test("watchTask times out when deadline elapses")
    func watchTaskTimeout() async throws {
        let token = try #require(WiroTaskToken(rawValue: "tok"))
        let clock = ControllableClock()
        let running: MockHTTPTransport.Handler = { _ in
            taskDetailResponse(status: "task_start")
        }
        let transport = MockHTTPTransport(handlers: [
            running, running, running, running, running,
        ])
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            pollInterval: .seconds(3),
            clock: clock.clock,
            sleeper: clock.sleeper
        )

        do {
            for try await _ in try await client.watchTask(
                token,
                timeout: .seconds(5)
            ) {}
            Issue.record("Expected timedOut")
        } catch let error as WiroError {
            guard case .timedOut(_, let timeout) = error else {
                Issue.record("Unexpected \(error)")
                return
            }
            #expect(timeout == .seconds(5))
        }

        // Polls at t=0 and t=3; remaining sleep 2s reaches deadline.
        #expect(clock.sleepDurations == [.seconds(3), .seconds(2)])
    }

    @Test("watchTask rejects non-positive timeout")
    func watchTaskValidation() async throws {
        let client = try await ClientFixtures.makeClient(
            transport: MockHTTPTransport()
        )
        let token = try #require(WiroTaskToken(rawValue: "tok"))
        do {
            _ = try await client.watchTask(token, timeout: .zero)
            Issue.record("Expected validation")
        } catch let error as WiroError {
            guard case .validation = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
    }

    @Test("cancelling the consumer stops polling with cancelled")
    func watchTaskCancellation() async throws {
        let token = try #require(WiroTaskToken(rawValue: "tok"))
        let transport = MockHTTPTransport { _ in
            taskDetailResponse(status: "task_start")
        }
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            pollInterval: .seconds(3),
            sleeper: { _ in
                try await Task.sleep(for: .seconds(3600))
            }
        )

        let consumer = Task {
            try await client.waitForTask(token, timeout: .seconds(600))
        }

        // Let the first snapshot arrive, then cancel during the sleep.
        try await Task.sleep(for: .milliseconds(50))
        consumer.cancel()

        do {
            _ = try await consumer.value
            Issue.record("Expected cancellation error")
        } catch let error as WiroError {
            #expect(error == .cancelled)
        } catch is CancellationError {
            Issue.record("Raw CancellationError leaked")
        }
        #expect(await transport.requestCount == 1)
    }

    @Test("subscribe polling success invokes onUpdate in order")
    func subscribeSuccess() async throws {
        let model = try WiroModelID(owner: "a", project: "b")
        let clock = ControllableClock()
        let transport = MockHTTPTransport(handlers: [
            { _ in runResponse(token: "tok") },
            { _ in taskDetailResponse(status: "task_queue") },
            { _ in taskDetailResponse(status: "task_start") },
            { _ in taskDetailResponse(
                status: "task_postprocess_end",
                pexit: 0
            ) },
        ])
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            pollInterval: .seconds(1),
            clock: clock.clock,
            sleeper: clock.sleeper
        )

        let box = UpdateBox()
        let result = try await client.subscribe(
            model,
            parameters: ["prompt": "hi"],
            timeout: .seconds(60),
            onUpdate: { update in box.append(update) }
        )

        guard case .success(let task) = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
        #expect(task.status == .completed)
        #expect(box.statuses == [.queued, .running, .completed])
        #expect(box.updates.last?.isTerminal == true)
    }

    @Test("subscribe maps non-zero exit to failure")
    func subscribeNonZeroExit() async throws {
        let model = try WiroModelID(owner: "a", project: "b")
        let clock = ControllableClock()
        let transport = MockHTTPTransport(handlers: [
            { _ in runResponse(token: "tok") },
            { _ in taskDetailResponse(
                status: "task_postprocess_end",
                pexit: 2
            ) },
        ])
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            clock: clock.clock,
            sleeper: clock.sleeper
        )

        let result = try await client.subscribe(
            model,
            timeout: .seconds(30)
        )
        guard case .failure(_, .nonZeroExit) = result else {
            Issue.record("Expected nonZeroExit, got \(result)")
            return
        }
    }

    @Test("subscribe maps cancelled task to failure")
    func subscribeCancelledTask() async throws {
        let model = try WiroModelID(owner: "a", project: "b")
        let clock = ControllableClock()
        let transport = MockHTTPTransport(handlers: [
            { _ in runResponse(token: "tok") },
            { _ in taskDetailResponse(status: "task_cancel") },
        ])
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            clock: clock.clock,
            sleeper: clock.sleeper
        )

        let result = try await client.subscribe(
            model,
            timeout: .seconds(30)
        )
        guard case .failure(_, .cancelled) = result else {
            Issue.record("Expected cancelled failure, got \(result)")
            return
        }
    }

    @Test("subscribe throws when run omits task token")
    func subscribeMissingToken() async throws {
        let model = try WiroModelID(owner: "a", project: "b")
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(
                status: 200,
                json: #"{"result":true,"taskid":"1"}"#
            )
        }
        let client = try await ClientFixtures.makeClient(transport: transport)

        do {
            _ = try await client.subscribe(model, timeout: .seconds(30))
            Issue.record("Expected unknownAPI")
        } catch let error as WiroError {
            guard case .unknownAPI = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
    }

    @Test("subscribe webSocket mode is unimplemented stub")
    func subscribeWebSocketStub() async throws {
        let model = try WiroModelID(owner: "a", project: "b")
        let transport = MockHTTPTransport { _ in
            runResponse(token: "tok")
        }
        let client = try await ClientFixtures.makeClient(transport: transport)

        do {
            _ = try await client.subscribe(
                model,
                timeout: .seconds(30),
                trackingMode: .webSocket
            )
            Issue.record("Expected unimplemented stub")
        } catch let error as WiroError {
            guard case .unknownAPI(let message, _, _) = error else {
                Issue.record("Unexpected \(error)")
                return
            }
            #expect(message.contains("WebSocket"))
        }
    }

    @Test("subscribeStream yields snapshots then finishes")
    func subscribeStreamSnapshots() async throws {
        let model = try WiroModelID(owner: "a", project: "b")
        let clock = ControllableClock()
        let transport = MockHTTPTransport(handlers: [
            { _ in runResponse(token: "tok") },
            { _ in taskDetailResponse(status: "task_start") },
            { _ in taskDetailResponse(
                status: "task_postprocess_end",
                pexit: 0
            ) },
        ])
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            pollInterval: .seconds(2),
            clock: clock.clock,
            sleeper: clock.sleeper
        )

        var updates: [WiroTaskUpdate] = []
        for try await update in try await client.subscribeStream(
            model,
            timeout: .seconds(60)
        ) {
            updates.append(update)
        }

        #expect(updates.count == 2)
        #expect(updates[0].status == .running)
        #expect(updates[0].isTerminal == false)
        #expect(updates[1].status == .completed)
        #expect(updates[1].isTerminal == true)
        #expect(clock.sleepDurations == [.seconds(2)])
    }

    @Test("WiroTaskUpdate event and binary accessors")
    func taskUpdateAccessors() {
        let task = WiroTask(
            status: .completed,
            statusRawValue: "task_postprocess_end",
            exitCode: 0,
            raw: [:]
        )
        let snapshot = WiroTaskUpdate.snapshot(task)
        #expect(snapshot.isTerminal)
        #expect(snapshot.status == .completed)

        let message = WiroSocketMessage(
            status: .running,
            statusRawValue: "task_start",
            raw: [:]
        )
        let event = WiroTaskUpdate.event(message)
        #expect(!event.isTerminal)
        #expect(event.status == .running)
        #expect(message.isTerminal == false)

        let terminalMessage = WiroSocketMessage(
            status: .cancelled,
            statusRawValue: "task_cancel",
            raw: [:]
        )
        #expect(WiroTaskUpdate.event(terminalMessage).isTerminal)

        let binary = WiroTaskUpdate.binary(Data([1, 2]))
        #expect(!binary.isTerminal)
        #expect(binary.status == nil)
    }
}

// MARK: - Helpers

private final class ControllableClock: @unchecked Sendable {
    private var now: Date
    private(set) var sleepDurations: [Duration] = []

    init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.now = now
    }

    var clock: WiroClock {
        { [self] in self.now }
    }

    var sleeper: WiroSleeper {
        { [self] duration in
            try Task.checkCancellation()
            self.sleepDurations.append(duration)
            self.now = self.now.addingTimeInterval(durationToSeconds(duration))
        }
    }
}

private final class UpdateBox: @unchecked Sendable {
    private var _updates: [WiroTaskUpdate] = []

    var updates: [WiroTaskUpdate] { _updates }

    var statuses: [WiroTaskStatus] {
        _updates.compactMap(\.status)
    }

    func append(_ update: WiroTaskUpdate) {
        _updates.append(update)
    }
}

private func durationToSeconds(_ duration: Duration) -> TimeInterval {
    let components = duration.components
    return TimeInterval(components.seconds)
        + TimeInterval(components.attoseconds)
        / 1_000_000_000_000_000_000
}

private func runResponse(token: String) -> (Data, HTTPURLResponse) {
    MockHTTP.response(
        status: 200,
        json: """
        {"result":true,"taskid":"1","socketaccesstoken":"\(token)"}
        """
    )
}

private func taskDetailResponse(
    status: String,
    pexit: Int? = nil
) -> (Data, HTTPURLResponse) {
    var fields = """
    "id":"1","socketaccesstoken":"tok","status":"\(status)"
    """
    if let pexit {
        fields += ",\"pexit\":\(pexit)"
    }
    return MockHTTP.response(
        status: 200,
        json: """
        {"tasklist":[{\(fields)}]}
        """
    )
}

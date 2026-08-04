import Foundation
import Testing
@testable import WiroKit

@Suite("WebSocket task tracking")
struct SocketTrackingTests {
    @Test("handshake sends task_info with task token")
    func handshake() async throws {
        let world = ScriptedSocketWorld()
        await world.session.configure(
            frames: [
                .text(socketJSON(type: "task_postprocess_end")),
            ]
        )
        let token = try #require(WiroTaskToken(rawValue: "tok-abc"))
        let client = try await ClientFixtures.makeClient(
            transport: MockHTTPTransport(),
            sleeper: parkingSleeper,
            socketSessionFactory: world.factory
        )

        for try await _ in try await client.watchTaskSocket(
            token,
            timeout: .seconds(30)
        ) {}

        let sent = await world.session.sentTexts
        #expect(sent == [#"{"type":"task_info","tasktoken":"tok-abc"}"#])
        #expect(await world.session.closeCount >= 1)
    }

    @Test("happy path yields progress then terminal and closes")
    func happyPath() async throws {
        let world = ScriptedSocketWorld()
        await world.session.configure(
            frames: [
                .text(socketJSON(type: "task_start", message: "running")),
                .text(socketJSON(
                    type: "task_postprocess_end",
                    message: [[
                        "name": "out.png",
                        "contenttype": "image/png",
                        "url": "https://cdn.wiro.ai/out.png",
                    ]]
                )),
            ]
        )
        let token = try #require(WiroTaskToken(rawValue: "tok"))
        let client = try await ClientFixtures.makeClient(
            transport: MockHTTPTransport(),
            sleeper: parkingSleeper,
            socketSessionFactory: world.factory
        )

        var events: [WiroSocketEvent] = []
        for try await event in try await client.watchTaskSocket(
            token,
            timeout: .seconds(60)
        ) {
            events.append(event)
        }

        #expect(events.count == 2)
        guard case .message(let first) = events[0] else {
            Issue.record("Expected message")
            return
        }
        #expect(first.status == .running)
        #expect(first.messageText == "running")

        guard case .message(let last) = events[1] else {
            Issue.record("Expected terminal message")
            return
        }
        #expect(last.status == .completed)
        #expect(last.isTerminal)
        #expect(last.outputs.count == 1)
        #expect(await world.session.closeCount >= 1)
    }

    @Test("binary frames pass through")
    func binaryFrames() async throws {
        let world = ScriptedSocketWorld()
        await world.session.configure(
            frames: [
                .binary(Data([1, 2, 3])),
                .text(socketJSON(type: "task_cancel", result: false)),
            ]
        )
        let token = try #require(WiroTaskToken(rawValue: "tok"))
        let client = try await ClientFixtures.makeClient(
            transport: MockHTTPTransport(),
            sleeper: parkingSleeper,
            socketSessionFactory: world.factory
        )

        var events: [WiroSocketEvent] = []
        for try await event in try await client.watchTaskSocket(token) {
            events.append(event)
        }

        #expect(events.count == 2)
        guard case .binary(let data) = events[0] else {
            Issue.record("Expected binary")
            return
        }
        #expect(data == Data([1, 2, 3]))
        guard case .message(let message) = events[1] else {
            Issue.record("Expected cancel message")
            return
        }
        #expect(message.status == .cancelled)
        #expect(await world.session.closeCount >= 1)
    }

    @Test("invalid JSON throws webSocket error and closes")
    func invalidJSON() async throws {
        let world = ScriptedSocketWorld()
        await world.session.configure(frames: [.text("not-json{")])
        let token = try #require(WiroTaskToken(rawValue: "tok"))
        let client = try await ClientFixtures.makeClient(
            transport: MockHTTPTransport(),
            sleeper: parkingSleeper,
            socketSessionFactory: world.factory
        )

        do {
            for try await _ in try await client.watchTaskSocket(token) {}
            Issue.record("Expected webSocket error")
        } catch let error as WiroError {
            guard case .webSocket(let message, _) = error else {
                Issue.record("Unexpected \(error)")
                return
            }
            #expect(message.contains("invalid JSON"))
        }
        #expect(await world.session.closeCount >= 1)
    }

    @Test("non-object JSON throws webSocket error")
    func nonObjectJSON() async throws {
        let world = ScriptedSocketWorld()
        await world.session.configure(frames: [.text("[1,2,3]")])
        let token = try #require(WiroTaskToken(rawValue: "tok"))
        let client = try await ClientFixtures.makeClient(
            transport: MockHTTPTransport(),
            sleeper: parkingSleeper,
            socketSessionFactory: world.factory
        )

        do {
            for try await _ in try await client.watchTaskSocket(token) {}
            Issue.record("Expected webSocket error")
        } catch let error as WiroError {
            guard case .webSocket(let message, _) = error else {
                Issue.record("Unexpected \(error)")
                return
            }
            #expect(message.contains("non-object"))
        }
        #expect(await world.session.closeCount >= 1)
    }

    @Test("premature close falls back to polling in subscribe")
    func prematureClosePollingFallback() async throws {
        let world = ScriptedSocketWorld()
        // Close immediately after handshake with no terminal event.
        await world.session.configure(frames: [], closeAfter: true)

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
            pollInterval: .seconds(1),
            clock: clock.clock,
            sleeper: { duration in
                // Socket timeout watcher parks; poll sleeper advances.
                if duration >= .seconds(30) {
                    try await Task.sleep(for: .seconds(3600))
                } else {
                    try await clock.sleeper(duration)
                }
            },
            socketSessionFactory: world.factory
        )

        let model = try WiroModelID(owner: "a", project: "b")
        let box = UpdateBox()
        let result = try await client.subscribe(
            model,
            timeout: .seconds(60),
            trackingMode: .webSocket,
            onUpdate: { box.append($0) }
        )

        guard case .success = result else {
            Issue.record("Expected success after polling fallback, got \(result)")
            return
        }
        #expect(box.updates.contains { update in
            if case .snapshot = update { return true }
            return false
        })
        #expect(await world.session.closeCount >= 1)
        #expect(await transport.requestCount == 3) // Run + 2 Detail
    }

    @Test("terminal socket event confirms via Task/Detail")
    func subscribeWebSocketSuccess() async throws {
        let world = ScriptedSocketWorld()
        await world.session.configure(
            frames: [
                .text(socketJSON(type: "task_start")),
                .text(socketJSON(type: "task_postprocess_end")),
            ]
        )
        let transport = MockHTTPTransport(handlers: [
            { _ in runResponse(token: "tok") },
            { _ in taskDetailResponse(
                status: "task_postprocess_end",
                pexit: 0
            ) },
        ])
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            sleeper: parkingSleeper,
            socketSessionFactory: world.factory
        )
        let model = try WiroModelID(owner: "a", project: "b")
        let box = UpdateBox()
        let result = try await client.subscribe(
            model,
            timeout: .seconds(60),
            trackingMode: .webSocket,
            onUpdate: { box.append($0) }
        )

        guard case .success = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
        #expect(box.statuses == [.running, .completed])
        #expect(await transport.requestCount == 2) // Run + Detail
        #expect(await world.session.closeCount >= 1)
    }

    @Test("socket timeout throws timedOut and closes")
    func socketTimeout() async throws {
        let world = ScriptedSocketWorld()
        await world.session.configure(frames: [], closeAfter: false)
        let clock = ControllableClock()
        let token = try #require(WiroTaskToken(rawValue: "tok"))
        let client = try await ClientFixtures.makeClient(
            transport: MockHTTPTransport(),
            clock: clock.clock,
            sleeper: clock.sleeper,
            socketSessionFactory: world.factory
        )

        do {
            for try await _ in try await client.watchTaskSocket(
                token,
                timeout: .seconds(5)
            ) {}
            Issue.record("Expected timedOut")
        } catch let error as WiroError {
            guard case .timedOut = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
        #expect(await world.session.closeCount >= 1)
    }

    @Test("cancellation closes the socket")
    func cancellationClosesSocket() async throws {
        let world = ScriptedSocketWorld()
        await world.session.configure(frames: [], closeAfter: false)
        let token = try #require(WiroTaskToken(rawValue: "tok"))
        let client = try await ClientFixtures.makeClient(
            transport: MockHTTPTransport(),
            sleeper: parkingSleeper,
            socketSessionFactory: world.factory
        )

        let streamConsumer = Task {
            do {
                for try await _ in try await client.watchTaskSocket(
                    token,
                    timeout: .seconds(600)
                ) {}
                return "finished"
            } catch let error as WiroError {
                return String(describing: error)
            } catch {
                return String(describing: error)
            }
        }
        try await Task.sleep(for: .milliseconds(50))
        streamConsumer.cancel()
        _ = await streamConsumer.value

        try await Task.sleep(for: .milliseconds(50))
        #expect(await world.session.closeCount >= 1)
    }

    @Test("proxy client connects directly to socketURL")
    func proxyConnectsToSocketURL() async throws {
        let world = ScriptedSocketWorld()
        await world.session.configure(
            frames: [.text(socketJSON(type: "task_postprocess_end"))]
        )
        let socketURL = URL(string: "wss://socket.wiro.ai/v1")!
        let client = try WiroClient(
            apiKey: nil,
            apiSecret: nil,
            proxyHeaders: ["Authorization": "Bearer tok"],
            authType: .proxy,
            baseURL: URL(string: "https://proxy.example.com/v1")!,
            socketURL: socketURL,
            transport: MockHTTPTransport(),
            socketSessionFactory: world.factory,
            pollInterval: .seconds(3),
            requestTimeout: .seconds(30),
            retryPolicy: .default,
            logger: nil,
            clock: { Date(timeIntervalSince1970: 1_700_000_000) },
            nonceProvider: { "0" },
            sleeper: parkingSleeper,
            jitterProvider: { 1.0 }
        )

        let token = try #require(WiroTaskToken(rawValue: "tok"))
        for try await _ in try await client.watchTaskSocket(
            token,
            timeout: .seconds(30)
        ) {}

        #expect(await world.session.connectedURL == socketURL)
        #expect(await client.authType == .proxy)
    }

    @Test("WiroSocketMessage parses progress payload")
    func progressPayload() {
        let json: WiroJSON = [
            "type": .string("task_start"),
            "result": .bool(true),
            "message": .object([
                "percentage": .number(40),
                "stepCurrent": .number(2),
                "stepTotal": .number(5),
            ]),
        ]
        let message = WiroSocketMessage.parse(json)
        #expect(message.progress?.percentage == 40)
        #expect(message.progress?.currentStep == 2)
        #expect(message.outputs.isEmpty)
    }

    @Test("watchTaskSocket rejects non-positive timeout")
    func validation() async throws {
        let client = try await ClientFixtures.makeClient(
            transport: MockHTTPTransport()
        )
        let token = try #require(WiroTaskToken(rawValue: "tok"))
        do {
            _ = try await client.watchTaskSocket(token, timeout: .zero)
            Issue.record("Expected validation")
        } catch let error as WiroError {
            guard case .validation = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
    }
}

// MARK: - Helpers

private func socketJSON(
    type: String,
    message: Any? = nil,
    result: Bool = true
) -> String {
    var object: [String: Any] = [
        "type": type,
        "id": "42",
        "tasktoken": "tok",
        "result": result,
    ]
    if let message {
        object["message"] = message
    }
    let data = try! JSONSerialization.data(withJSONObject: object)
    return String(decoding: data, as: UTF8.self)
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

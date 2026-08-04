import Foundation
import Testing
@testable import WiroKit

@Suite("Edge case behavior")
struct EdgeCaseTests {
    @Test("public apiKey and proxy inits succeed")
    func publicInits() async throws {
        let transport = MockHTTPTransport()
        let keyClient = try WiroClient(
            apiKey: "key",
            transport: transport
        )
        #expect(await keyClient.authType == .apiKey)

        let signed = try WiroClient(
            apiKey: "key",
            apiSecret: "secret",
            transport: transport
        )
        #expect(await signed.authType == .signature)

        let proxy = try WiroClient(
            proxyURL: URL(string: "https://proxy.example.com/v1")!,
            headers: ["Authorization": "Bearer x"],
            transport: transport
        )
        #expect(await proxy.authType == .proxy)
        #expect(
            await proxy.baseURL.absoluteString
                == "https://proxy.example.com/v1"
        )
    }

    @Test("socket payload accessors and progress string decoding")
    func socketPayloadAccessors() {
        let log = WiroSocketMessage(
            status: .running,
            statusRawValue: "task_start",
            payload: .log("hi"),
            raw: [:]
        )
        #expect(log.messageText == "hi")
        #expect(log.progress == nil)

        let progressJSON: WiroJSON = [
            "type": .string("task_start"),
            "message": .string(
                #"{"percentage":12,"stepCurrent":1,"stepTotal":10}"#
            ),
        ]
        let fromString = WiroSocketMessage.parse(progressJSON)
        #expect(fromString.progress?.percentage == 12)

        let unknown = WiroSocketMessage(
            status: .running,
            statusRawValue: "task_start",
            payload: .unknown(.number(1)),
            raw: [:]
        )
        #expect(unknown.messageText == nil)
        #expect(unknown.progress == nil)
        #expect(unknown.outputs.isEmpty)

        #expect(
            WiroSocketTiming.timeInterval(.milliseconds(1500)) == 1.5
        )
        #expect(
            WiroClient.timeoutDescription(.milliseconds(500))
                .contains("0.5")
        )
    }

    @Test("subscribeStream webSocket yields events then finishes")
    func subscribeStreamWebSocket() async throws {
        let world = ScriptedSocketWorld()
        await world.session.configure(
            frames: [
                .text(
                    #"{"type":"task_postprocess_end","result":true}"#
                ),
            ]
        )
        let transport = MockHTTPTransport(handlers: [
            { _ in
                MockHTTP.response(
                    status: 200,
                    json:
                        #"{"result":true,"taskid":"1","socketaccesstoken":"tok"}"#
                )
            },
            { _ in
                MockHTTP.response(
                    status: 200,
                    json: #"""
                    {"tasklist":[{
                      "id":"1",
                      "socketaccesstoken":"tok",
                      "status":"task_postprocess_end",
                      "pexit":0
                    }]}
                    """#
                )
            },
        ])
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            sleeper: parkingSleeper,
            socketSessionFactory: world.factory
        )
        let model = try WiroModelID(owner: "a", project: "b")
        var count = 0
        for try await update in try await client.subscribeStream(
            model,
            timeout: .seconds(30),
            trackingMode: .webSocket
        ) {
            count += 1
            #expect(update.isTerminal || update.status == .completed)
        }
        #expect(count == 1)
    }

    @Test("WebSocket session close is idempotent")
    func webSocketCloseIsIdempotent() async {
        let session = URLSessionWebSocketSession.connect(
            url: URL(string: "wss://127.0.0.1:9/v1")!,
            timeout: .milliseconds(50)
        )
        await session.close()
        await session.close()
    }

    @Test("log levels are comparable")
    func logLevelOrdering() {
        #expect(WiroLogLevel.debug < .info)
        #expect(WiroLogLevel.info < .warning)
        #expect(WiroLogLevel.warning < .error)
    }

    @Test("path without leading slash still posts")
    func pathWithoutSlash() async throws {
        let transport = MockHTTPTransport { request in
            #expect(request.url?.absoluteString.hasSuffix("/Tool/List") == true)
            return MockHTTP.response(status: 200, json: #"{}"#)
        }
        let client = try await ClientFixtures.makeClient(transport: transport)
        _ = try await client.post("Tool/List", body: [:], parse: { $0 })
    }

    @Test("empty 2xx body succeeds as empty object")
    func emptySuccessBody() async throws {
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(status: 204, data: Data())
        }
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            retryPolicy: .none
        )
        let object = try await client.post("/X", body: [:], parse: { $0 })
        #expect(object.isEmpty)
    }

    @Test("empty error body uses default message")
    func emptyErrorBody() async throws {
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(status: 500, data: Data())
        }
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            retryPolicy: .none
        )
        do {
            _ = try await client.post("/X", body: [:], parse: { $0 })
            Issue.record("Expected error")
        } catch let error as WiroError {
            guard case .unknownAPI(let message, 500, _) = error else {
                Issue.record("Unexpected \(error)")
                return
            }
            #expect(message == "Wiro API request failed.")
        }
    }

    @Test("error code may be an integer")
    func integerErrorCode() async throws {
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(
                status: 200,
                json: #"""
                {"result":false,"errors":[{"code":42,"message":"nope"}]}
                """#
            )
        }
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            retryPolicy: .none
        )
        do {
            _ = try await client.post("/X", body: [:], parse: { $0 })
            Issue.record("Expected apiResult")
        } catch let error as WiroError {
            guard case .apiResult(_, let code, _, _) = error else {
                Issue.record("Unexpected \(error)")
                return
            }
            #expect(code == "42")
        }
    }

    @Test("non-JSON error body uses raw string as message")
    func nonJSONErrorBody() async throws {
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(status: 502, data: Data("bad gateway".utf8))
        }
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            retryPolicy: .none
        )
        do {
            _ = try await client.post("/X", body: [:], parse: { $0 })
            Issue.record("Expected error")
        } catch let error as WiroError {
            guard case .unknownAPI(let message, 502, _) = error else {
                Issue.record("Unexpected \(error)")
                return
            }
            #expect(message == "bad gateway")
        }
    }

    @Test("missing host and missing scheme are rejected")
    func missingHostAndScheme() {
        #expect(throws: WiroError.self) {
            try WiroClient(
                apiKey: "key",
                baseURL: URL(string: "https:///v1")!
            )
        }
        // Relative URL has no scheme.
        #expect(throws: WiroError.self) {
            try WiroClient(
                apiKey: "key",
                baseURL: URL(fileURLWithPath: "/tmp")
            )
        }
    }

    @Test("422 maps to validation")
    func unprocessable() async throws {
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(status: 422, json: #"{"message":"nope"}"#)
        }
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            retryPolicy: .none
        )
        do {
            _ = try await client.post("/X", body: [:], parse: { $0 })
            Issue.record("Expected validation")
        } catch let error as WiroError {
            guard case .validation(_, 422, _) = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
    }

    @Test("403 maps to authentication")
    func forbidden() async throws {
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(status: 403, json: #"{"message":"no"}"#)
        }
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            retryPolicy: .none
        )
        do {
            _ = try await client.post("/X", body: [:], parse: { $0 })
            Issue.record("Expected authentication")
        } catch let error as WiroError {
            guard case .authentication(_, 403, _) = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
    }

    @Test("missing result key counts as success")
    func missingResultKey() async throws {
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(status: 200, json: #"{"tool":[]}"#)
        }
        let client = try await ClientFixtures.makeClient(transport: transport)
        let object = try await client.post("/X", body: [:], parse: { $0 })
        #expect(object["tool"] != nil)
    }

    @Test("sleeper cancellation during retry maps to cancelled")
    func sleeperCancellation() async throws {
        let transport = MockHTTPTransport(handlers: [
            { _ in MockHTTP.response(status: 503, json: #"{"message":"x"}"#) },
            { _ in MockHTTP.response(status: 200, json: #"{}"#) },
        ])
        let client = try WiroClient(
            apiKey: "key",
            apiSecret: nil,
            proxyHeaders: [:],
            authType: .apiKey,
            baseURL: WiroClient.defaultBaseURL,
            socketURL: WiroClient.defaultSocketURL,
            transport: transport,
            pollInterval: .seconds(3),
            requestTimeout: .seconds(30),
            retryPolicy: .default,
            logger: nil,
            clock: { Date() },
            nonceProvider: { "0" },
            sleeper: { _ in throw CancellationError() },
            jitterProvider: { 1.0 }
        )
        do {
            _ = try await client.post("/X", body: [:], parse: { $0 })
            Issue.record("Expected cancelled")
        } catch let error as WiroError {
            #expect(error == .cancelled)
        }
    }

    @Test("HTTP transport supports default and custom sessions")
    func httpTransportSessionConfiguration() {
        let transport = URLSessionHTTPTransport()
        #expect(transport.session === URLSession.shared)

        let custom = URLSessionHTTPTransport(
            session: URLSession(configuration: .ephemeral)
        )
        #expect(custom.session !== URLSession.shared)
    }

    @Test("mapTransportError covers cancellation and network")
    func mapTransportError() {
        #expect(
            URLSessionHTTPTransport.mapTransportError(CancellationError())
                == .cancelled
        )
        let network = URLSessionHTTPTransport.mapTransportError(
            URLError(.timedOut)
        )
        guard case .network = network else {
            Issue.record("Expected network")
            return
        }
        let passthrough = URLSessionHTTPTransport.mapTransportError(
            WiroError.cancelled
        )
        #expect(passthrough == .cancelled)
    }
}

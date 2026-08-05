import Foundation
import Testing
@testable import WiroKit

@Suite("WiroRetryPolicy")
struct WiroRetryPolicyTests {
    @Test("default policy uses documented retry settings")
    func defaults() {
        let policy = WiroRetryPolicy.default
        #expect(policy.maxRetries == 2)
        #expect(policy.initialDelay == .milliseconds(500))
        #expect(policy.maximumDelay == .seconds(4))
        #expect(policy.multiplier == 2.0)
        #expect(
            policy.retryableStatusCodes
                == [408, 429, 500, 502, 503, 504]
        )
    }

    @Test("deterministic jittered delays with fixed generator")
    func deterministicDelays() {
        var generator = ConstantGenerator(value: 0)
        // nextDouble path via Double.random: with a constant zero-ish
        // generator, assert via explicit jitterFactor instead.
        let policy = WiroRetryPolicy.default

        let d0 = policy.delay(forRetryIndex: 0, jitterFactor: 1.0)
        #expect(d0 == .milliseconds(500))

        let d1 = policy.delay(forRetryIndex: 1, jitterFactor: 1.0)
        #expect(d1 == .seconds(1))

        let d2 = policy.delay(forRetryIndex: 2, jitterFactor: 1.0)
        #expect(d2 == .seconds(2))

        let capped = policy.delay(forRetryIndex: 10, jitterFactor: 1.0)
        #expect(capped == .seconds(4))

        let low = policy.delay(forRetryIndex: 0, jitterFactor: 0.8)
        #expect(low == .milliseconds(400))

        let high = policy.delay(forRetryIndex: 0, jitterFactor: 1.2)
        #expect(high == .milliseconds(600))

        // RNG-based API remains callable.
        let fromRNG = policy.delay(
            forRetryIndex: 0,
            using: &generator
        )
        #expect(fromRNG >= .milliseconds(400))
        #expect(fromRNG <= .milliseconds(600))
    }

    @Test("none policy never retries")
    func nonePolicy() {
        #expect(WiroRetryPolicy.none.maxRetries == 0)
        #expect(WiroRetryPolicy.none.retryableStatusCodes.isEmpty)
    }
}

struct ConstantGenerator: RandomNumberGenerator {
    var value: UInt64
    mutating func next() -> UInt64 { value }
}

@Suite("WiroClient configuration")
struct WiroClientConfigurationTests {
    @Test("empty apiKey throws validation")
    func emptyAPIKey() {
        #expect(throws: WiroError.self) {
            try WiroClient(apiKey: "  ")
        }
    }

    @Test("whitespace apiSecret throws validation")
    func whitespaceSecret() {
        #expect(throws: WiroError.self) {
            try WiroClient(apiKey: "key", apiSecret: "  ")
        }
    }

    @Test("invalid baseURL schemes and components throw")
    func invalidBaseURL() throws {
        #expect(throws: WiroError.self) {
            try WiroClient(
                apiKey: "key",
                baseURL: URL(string: "ftp://api.wiro.ai/v1")!
            )
        }
        #expect(throws: WiroError.self) {
            try WiroClient(
                apiKey: "key",
                baseURL: URL(string: "https://user:pass@api.wiro.ai/v1")!
            )
        }
        #expect(throws: WiroError.self) {
            try WiroClient(
                apiKey: "key",
                baseURL: URL(string: "https://api.wiro.ai/v1?x=1")!
            )
        }
        #expect(throws: WiroError.self) {
            try WiroClient(
                apiKey: "key",
                baseURL: URL(string: "https://api.wiro.ai/v1#frag")!
            )
        }
    }

    @Test("invalid socketURL throws")
    func invalidSocketURL() {
        #expect(throws: WiroError.self) {
            try WiroClient(
                apiKey: "key",
                socketURL: URL(string: "https://socket.wiro.ai/v1")!
            )
        }
    }

    @Test("trailing slashes are trimmed from baseURL")
    func trimsTrailingSlashes() async throws {
        let transport = MockHTTPTransport()
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            baseURL: URL(string: "https://api.wiro.ai/v1///")!
        )
        #expect(await client.baseURL.absoluteString == "https://api.wiro.ai/v1")
    }

    @Test("authType reflects credentials")
    func authTypes() async throws {
        let transport = MockHTTPTransport()
        let keyOnly = try await ClientFixtures.makeClient(
            transport: transport
        )
        #expect(await keyOnly.authType == .apiKey)

        let signed = try await ClientFixtures.makeClient(
            transport: transport,
            apiSecret: ClientFixtures.apiSecret
        )
        #expect(await signed.authType == .signature)

        let proxy = try await ClientFixtures.makeProxyClient(
            transport: transport
        )
        #expect(await proxy.authType == .proxy)
    }
}

@Suite("WiroClient auth headers")
struct WiroClientAuthTests {
    @Test("signature matches known HMAC-SHA256 vector")
    func signatureVector() {
        let hex = WiroClient.signature(
            apiKey: ClientFixtures.apiKey,
            apiSecret: ClientFixtures.apiSecret,
            nonce: ClientFixtures.nonce
        )
        #expect(hex == ClientFixtures.expectedSignature)
        #expect(hex == hex.lowercased())
    }

    @Test("apiKey mode sends x-api-key and Content-Type")
    func apiKeyHeaders() async throws {
        let transport = MockHTTPTransport()
        let client = try await ClientFixtures.makeClient(
            transport: transport
        )
        let headers = await client.authHeaders(includeContentType: true)
        #expect(headers["x-api-key"] == ClientFixtures.apiKey)
        #expect(headers["Content-Type"] == "application/json")
        #expect(headers["User-Agent"] == "WiroKit/\(WiroKitInfo.version)")
        #expect(headers["x-nonce"] == nil)
        #expect(headers["x-signature"] == nil)
    }

    @Test("signature mode sends nonce and signature")
    func signatureHeaders() async throws {
        let transport = MockHTTPTransport()
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            apiSecret: ClientFixtures.apiSecret
        )
        let headers = await client.authHeaders(includeContentType: true)
        #expect(headers["x-api-key"] == ClientFixtures.apiKey)
        #expect(headers["x-nonce"] == ClientFixtures.nonce)
        #expect(headers["x-signature"] == ClientFixtures.expectedSignature)
        #expect(headers["Content-Type"] == "application/json")
        #expect(headers["User-Agent"] == "WiroKit/\(WiroKitInfo.version)")
    }

    @Test("multipart auth omits JSON Content-Type")
    func multipartHeaders() async throws {
        let transport = MockHTTPTransport()
        let client = try await ClientFixtures.makeClient(
            transport: transport
        )
        let headers = await client.authHeaders(includeContentType: false)
        #expect(headers["Content-Type"] == nil)
        #expect(headers["x-api-key"] == ClientFixtures.apiKey)
        #expect(headers["User-Agent"] == "WiroKit/\(WiroKitInfo.version)")
    }

    @Test("proxy mode sends static headers only")
    func proxyHeaders() async throws {
        let transport = MockHTTPTransport()
        let client = try await ClientFixtures.makeProxyClient(
            transport: transport,
            headers: ["Authorization": "Bearer tok", "X-Custom": "1"]
        )
        let headers = await client.authHeaders(includeContentType: true)
        #expect(headers["Authorization"] == "Bearer tok")
        #expect(headers["X-Custom"] == "1")
        #expect(headers["x-api-key"] == nil)
        #expect(headers["Content-Type"] == "application/json")
        #expect(headers["User-Agent"] == "WiroKit/\(WiroKitInfo.version)")
    }
}

@Suite("WiroClient envelope")
struct WiroClientEnvelopeTests {
    @Test("200 with result false maps to apiResult")
    func resultFalse() async throws {
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(
                status: 200,
                json: #"""
                {"result":false,"errors":[{"code":"E1","message":"nope"}]}
                """#
            )
        }
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            retryPolicy: .none
        )
        do {
            _ = try await client.post("/Tool/List", body: [:], parse: { $0 })
            Issue.record("Expected apiResult error")
        } catch let error as WiroError {
            guard case .apiResult(
                let message,
                let code,
                let status,
                _
            ) = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
            #expect(message == "nope")
            #expect(code == "E1")
            #expect(status == 200)
        }
    }

    @Test("401 maps to authentication")
    func unauthorized() async throws {
        try await expectError(
            status: 401,
            json: #"{"message":"denied"}"#,
            matching: { if case .authentication(let m, 401, _) = $0 {
                return m == "denied"
            }; return false }
        )
    }

    @Test("400 maps to validation")
    func badRequest() async throws {
        try await expectError(
            status: 400,
            json: #"{"errors":[{"message":"bad"}]}"#,
            matching: { if case .validation(let m, 400, _) = $0 {
                return m == "bad"
            }; return false }
        )
    }

    @Test("429 maps to rateLimited with Retry-After")
    func rateLimitedWithRetryAfter() async throws {
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(
                status: 429,
                json: #"{"message":"slow"}"#,
                headerFields: ["Retry-After": "7"]
            )
        }
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            retryPolicy: .none
        )
        do {
            _ = try await client.post("/X", body: [:], parse: { $0 })
            Issue.record("Expected rateLimited")
        } catch let error as WiroError {
            guard case .rateLimited(let message, 429, let retry, _) = error
            else {
                Issue.record("Unexpected \(error)")
                return
            }
            #expect(message == "slow")
            #expect(retry == 7)
        }
    }

    @Test("429 without Retry-After still rateLimited")
    func rateLimitedWithoutRetryAfter() async throws {
        try await expectError(
            status: 429,
            json: #"{"message":"slow"}"#,
            matching: { if case .rateLimited(let m, 429, nil, _) = $0 {
                return m == "slow"
            }; return false }
        )
    }

    @Test("500 maps to unknownAPI")
    func serverError() async throws {
        try await expectError(
            status: 500,
            json: #"{"message":"boom"}"#,
            matching: { if case .unknownAPI(let m, 500, _) = $0 {
                return m == "boom"
            }; return false }
        )
    }

    @Test("invalid JSON on 200 maps to unknownAPI")
    func invalidJSON() async throws {
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(status: 200, data: Data("not-json".utf8))
        }
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            retryPolicy: .none
        )
        do {
            _ = try await client.post("/X", body: [:], parse: { $0 })
            Issue.record("Expected unknownAPI")
        } catch let error as WiroError {
            guard case .unknownAPI(_, 200, _) = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
    }

    @Test("non-object JSON maps to unknownAPI")
    func nonObjectJSON() async throws {
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(status: 200, json: "[1,2,3]")
        }
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            retryPolicy: .none
        )
        do {
            _ = try await client.post("/X", body: [:], parse: { $0 })
            Issue.record("Expected unknownAPI")
        } catch let error as WiroError {
            guard case .unknownAPI(let message, 200, _) = error else {
                Issue.record("Unexpected \(error)")
                return
            }
            #expect(message.contains("non-object"))
        }
    }

    @Test("successful object is returned to parse")
    func successParse() async throws {
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(
                status: 200,
                json: #"{"result":true,"tool":[]}"#
            )
        }
        let client = try await ClientFixtures.makeClient(
            transport: transport
        )
        let value: String = try await client.post(
            "/Tool/List",
            body: ["start": "0"],
            parse: { object in
                JSONReader.boolean(object, "result") == true
                    ? "ok"
                    : "bad"
            }
        )
        #expect(value == "ok")
        #expect(await transport.requestCount == 1)
    }

    private func expectError(
        status: Int,
        json: String,
        matching: @Sendable (WiroError) -> Bool
    ) async throws {
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(status: status, json: json)
        }
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            retryPolicy: .none
        )
        do {
            _ = try await client.post("/X", body: [:], parse: { $0 })
            Issue.record("Expected error for status \(status)")
        } catch let error as WiroError {
            #expect(matching(error))
        }
    }
}

@Suite("WiroClient retry")
struct WiroClientRetryTests {
    @Test("retries transient 503 then succeeds")
    func retriesThenSucceeds() async throws {
        let transport = MockHTTPTransport(handlers: [
            { _ in MockHTTP.response(status: 503, json: #"{"message":"x"}"#) },
            { _ in MockHTTP.response(status: 200, json: #"{"ok":true}"#) },
        ])
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            retryPolicy: .default,
            jitter: 1.0
        )
        let object = try await client.post("/X", body: [:], parse: { $0 })
        #expect(JSONReader.boolean(object, "ok") == true)
        #expect(await transport.requestCount == 2)
    }

    @Test("respects maxRetries")
    func respectsMaxRetries() async throws {
        let transport = MockHTTPTransport(handlers: [
            { _ in MockHTTP.response(status: 503, json: #"{"message":"a"}"#) },
            { _ in MockHTTP.response(status: 503, json: #"{"message":"b"}"#) },
            { _ in MockHTTP.response(status: 503, json: #"{"message":"c"}"#) },
        ])
        let policy = WiroRetryPolicy(
            maxRetries: 2,
            initialDelay: .milliseconds(1),
            maximumDelay: .milliseconds(1),
            multiplier: 1,
            retryableStatusCodes: [503]
        )
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            retryPolicy: policy
        )
        do {
            _ = try await client.post("/X", body: [:], parse: { $0 })
            Issue.record("Expected failure")
        } catch let error as WiroError {
            guard case .unknownAPI(_, 503, _) = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
        // initial + 2 retries = 3
        #expect(await transport.requestCount == 3)
    }

    @Test("retryable false disables retries")
    func noRetryWhenDisabled() async throws {
        let transport = MockHTTPTransport(handlers: [
            { _ in MockHTTP.response(status: 503, json: #"{"message":"x"}"#) },
            { _ in MockHTTP.response(status: 200, json: #"{}"#) },
        ])
        let client = try await ClientFixtures.makeClient(
            transport: transport
        )
        do {
            _ = try await client.post(
                "/Run/a/b",
                body: [:],
                retryable: false,
                parse: { $0 }
            )
            Issue.record("Expected failure")
        } catch let error as WiroError {
            guard case .unknownAPI(_, 503, _) = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
        #expect(await transport.requestCount == 1)
    }

    @Test("network errors are retried")
    func retriesNetworkErrors() async throws {
        let transport = MockHTTPTransport(handlers: [
            { _ in throw WiroError.network(message: "down", underlying: nil) },
            { _ in MockHTTP.response(status: 200, json: #"{"ok":1}"#) },
        ])
        let client = try await ClientFixtures.makeClient(
            transport: transport
        )
        let object = try await client.post("/X", body: [:], parse: { $0 })
        #expect(JSONReader.integer(object, "ok") == 1)
        #expect(await transport.requestCount == 2)
    }

    @Test("429 honors Retry-After as minimum delay")
    func retryAfterMinimum() async throws {
        nonisolated(unsafe) var slept: [Duration] = []
        let transport = MockHTTPTransport(handlers: [
            { _ in
                MockHTTP.response(
                    status: 429,
                    json: #"{"message":"slow"}"#,
                    headerFields: ["Retry-After": "3"]
                )
            },
            { _ in MockHTTP.response(status: 200, json: #"{}"#) },
        ])
        let policy = WiroRetryPolicy(
            maxRetries: 1,
            initialDelay: .milliseconds(100),
            maximumDelay: .seconds(10),
            multiplier: 1,
            retryableStatusCodes: [429]
        )
        let client = try WiroClient(
            apiKey: ClientFixtures.apiKey,
            apiSecret: nil,
            proxyHeaders: [:],
            authType: .apiKey,
            baseURL: WiroClient.defaultBaseURL,
            socketURL: WiroClient.defaultSocketURL,
            transport: transport,
            pollInterval: .seconds(3),
            requestTimeout: .seconds(30),
            retryPolicy: policy,
            logger: nil,
            clock: { Date() },
            nonceProvider: { "0" },
            sleeper: { duration in slept.append(duration) },
            jitterProvider: { 1.0 }
        )
        _ = try await client.post("/X", body: [:], parse: { $0 })
        #expect(slept.count == 1)
        #expect(slept[0] == .seconds(3))
    }
}

@Suite("WiroClient cancellation")
struct WiroClientCancellationTests {
    @Test("cancelled task surfaces WiroError.cancelled")
    func cancellation() async throws {
        let transport = MockHTTPTransport { _ in
            try await Task.sleep(for: .seconds(5))
            return MockHTTP.response(status: 200, json: #"{}"#)
        }
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            sleeper: { _ in try await Task.sleep(for: .seconds(5)) }
        )

        let task = Task {
            try await client.post("/X", body: [:], parse: { $0 })
        }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch let error as WiroError {
            #expect(error == .cancelled)
        } catch is CancellationError {
            // Also acceptable if surfaced before mapping; prefer WiroError.
            Issue.record("Raw CancellationError leaked")
        }
    }
}

@Suite("WiroClient logging")
struct WiroClientLoggingTests {
    @Test("successful call emits debug then info")
    func successLogSequence() async throws {
        let store = LogStore()
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(status: 200, json: #"{}"#)
        }
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            logger: { store.append($0) }
        )
        _ = try await client.post("/Tool/List", body: [:], parse: { $0 })
        let events = store.snapshot()
        #expect(events.count >= 2)
        #expect(events[0].level == .debug)
        #expect(events[0].message == "Starting request.")
        #expect(events[1].level == .info)
        #expect(events[1].statusCode == 200)
        assertNoSecrets(in: events)
    }

    @Test("retried call emits warning then success")
    func retryLogSequence() async throws {
        let store = LogStore()
        let transport = MockHTTPTransport(handlers: [
            { _ in MockHTTP.response(status: 503, json: #"{"message":"x"}"#) },
            { _ in MockHTTP.response(status: 200, json: #"{}"#) },
        ])
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            logger: { store.append($0) }
        )
        _ = try await client.post("/X", body: [:], parse: { $0 })
        let events = store.snapshot()
        #expect(events.contains { $0.level == .warning })
        #expect(events.contains { $0.level == .info && $0.statusCode == 200 })
        assertNoSecrets(in: events)
    }

    @Test("final failure emits error level")
    func failureLog() async throws {
        let store = LogStore()
        let transport = MockHTTPTransport { _ in
            MockHTTP.response(status: 400, json: #"{"message":"bad"}"#)
        }
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            retryPolicy: .none,
            logger: { store.append($0) }
        )
        _ = try? await client.post("/X", body: [:], parse: { $0 })
        let events = store.snapshot()
        #expect(events.contains { $0.level == .error })
        assertNoSecrets(in: events)
    }

    @Test("malformed JSON handler logs debug without body")
    func malformedJSONLog() async throws {
        let store = LogStore()
        let transport = MockHTTPTransport()
        let client = try await ClientFixtures.makeClient(
            transport: transport,
            logger: { store.append($0) }
        )
        let handler = await client.malformedJSONHandler()
        handler(#"{"apiKey":"test-api-key","secret":"test-secret"}"#)
        let events = store.snapshot()
        #expect(events.count == 1)
        #expect(events[0].level == .debug)
        #expect(events[0].message.contains("length"))
        assertNoSecrets(in: events)
    }

    private func assertNoSecrets(in events: [WiroLogEvent]) {
        for event in events {
            #expect(!event.message.contains(ClientFixtures.apiKey))
            #expect(!event.message.contains(ClientFixtures.apiSecret))
            #expect(!(event.error?.contains(ClientFixtures.apiKey) ?? false))
            #expect(!(event.error?.contains(ClientFixtures.apiSecret) ?? false))
            #expect(!(event.url?.contains(ClientFixtures.apiKey) ?? false))
        }
    }
}

final class LogStore: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [WiroLogEvent] = []

    func append(_ event: WiroLogEvent) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }

    func snapshot() -> [WiroLogEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}

import Foundation
@testable import WiroKit

/// Scripted HTTP transport for unit tests. Never hits the network.
actor MockHTTPTransport: WiroHTTPTransport {
    typealias Handler = @Sendable (URLRequest) async throws -> (
        Data,
        HTTPURLResponse
    )

    private(set) var requests: [URLRequest] = []
    private var handlers: [Handler]

    init(handlers: [Handler] = []) {
        self.handlers = handlers
    }

    init(handler: @escaping Handler) {
        self.handlers = [handler]
    }

    func enqueue(_ handler: @escaping Handler) {
        handlers.append(handler)
    }

    func perform(
        _ request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !handlers.isEmpty else {
            throw WiroError.network(
                message: "MockHTTPTransport has no queued handlers.",
                underlying: nil
            )
        }
        let handler = handlers.removeFirst()
        return try await handler(request)
    }

    var requestCount: Int { requests.count }

    func request(at index: Int) -> URLRequest? {
        guard requests.indices.contains(index) else { return nil }
        return requests[index]
    }
}

enum MockHTTP {
    static func response(
        status: Int,
        json: String,
        headerFields: [String: String] = [:],
        url: URL = URL(string: "https://api.wiro.ai/v1/test")!
    ) -> (Data, HTTPURLResponse) {
        let data = Data(json.utf8)
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headerFields
        )!
        return (data, response)
    }

    static func response(
        status: Int,
        data: Data,
        headerFields: [String: String] = [:],
        url: URL = URL(string: "https://api.wiro.ai/v1/test")!
    ) -> (Data, HTTPURLResponse) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headerFields
        )!
        return (data, response)
    }
}

enum ClientFixtures {
    static let apiKey = "test-api-key"
    static let apiSecret = "test-secret"
    static let nonce = "1700000000000"
    /// Independently computed:
    /// HMAC-SHA256(key=UTF8(apiKey), msg=UTF8(apiSecret+nonce)) hex.
    static let expectedSignature =
        "2d99fa1b6934f66a712785d1b402997e1b13d9d7cd5e0085211dac133ae4a8ef"

    static func makeClient(
        transport: MockHTTPTransport,
        apiKey: String = apiKey,
        apiSecret: String? = nil,
        baseURL: URL = WiroClient.defaultBaseURL,
        socketURL: URL = WiroClient.defaultSocketURL,
        retryPolicy: WiroRetryPolicy = .default,
        logger: WiroLogger? = nil,
        nonce: String = nonce,
        jitter: Double = 1.0,
        sleeper: WiroSleeper? = nil
    ) async throws -> WiroClient {
        let authType: WiroAuthType =
            (apiSecret?.isEmpty == false) ? .signature : .apiKey
        return try WiroClient(
            apiKey: apiKey,
            apiSecret: apiSecret,
            proxyHeaders: [:],
            authType: authType,
            baseURL: baseURL,
            socketURL: socketURL,
            transport: transport,
            pollInterval: .seconds(3),
            requestTimeout: .seconds(30),
            retryPolicy: retryPolicy,
            logger: logger,
            clock: { Date(timeIntervalSince1970: 1_700_000_000) },
            nonceProvider: { nonce },
            sleeper: sleeper ?? { _ in },
            jitterProvider: { jitter }
        )
    }

    static func makeProxyClient(
        transport: MockHTTPTransport,
        proxyURL: URL = URL(string: "https://proxy.example.com/v1")!,
        headers: [String: String] = ["Authorization": "Bearer tok"],
        logger: WiroLogger? = nil,
        retryPolicy: WiroRetryPolicy = .default
    ) async throws -> WiroClient {
        try WiroClient(
            apiKey: nil,
            apiSecret: nil,
            proxyHeaders: headers,
            authType: .proxy,
            baseURL: proxyURL,
            socketURL: WiroClient.defaultSocketURL,
            transport: transport,
            pollInterval: .seconds(3),
            requestTimeout: .seconds(30),
            retryPolicy: retryPolicy,
            logger: logger,
            clock: { Date() },
            nonceProvider: { "0" },
            sleeper: { _ in },
            jitterProvider: { 1.0 }
        )
    }
}

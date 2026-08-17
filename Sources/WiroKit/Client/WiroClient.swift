import CryptoKit
import Foundation

/// Sleeps for a duration; injectable so tests avoid real waits.
typealias WiroSleeper = @Sendable (Duration) async throws -> Void

/// Supplies the current instant; injectable for deterministic tests.
typealias WiroClock = @Sendable () -> Date

/// Supplies a millisecond-nonce string; injectable for signature vectors.
typealias WiroNonceProvider = @Sendable () -> String

/// Supplies a jitter factor in `[0.8, 1.2]` for retry backoff.
typealias WiroJitterProvider = @Sendable () -> Double

/// Client for the Wiro AI REST and WebSocket APIs.
///
/// Construct with an API key (and optional secret for signature auth) or
/// in proxy mode with static headers. All networking goes through an
/// injectable `WiroHTTPTransport` so unit tests never hit the network.
public actor WiroClient {
    /// Default REST base URL.
    public static let defaultBaseURL: URL = {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.wiro.ai"
        components.path = "/v1"
        return components.url!
    }()

    /// Default WebSocket URL.
    public static let defaultSocketURL: URL = {
        var components = URLComponents()
        components.scheme = "wss"
        components.host = "socket.wiro.ai"
        components.path = "/v1"
        return components.url!
    }()

    /// Configured authentication mode.
    public let authType: WiroAuthType

    /// REST base URL with trailing slashes removed.
    public let baseURL: URL

    /// WebSocket endpoint URL.
    public let socketURL: URL

    /// Interval between task-status polling requests.
    public let pollInterval: Duration

    /// Per-attempt HTTP / WebSocket connect timeout.
    public let requestTimeout: Duration

    /// Retry policy for transient failures.
    public let retryPolicy: WiroRetryPolicy

    let apiKey: String?
    let apiSecret: String?
    let proxyHeaders: [String: String]
    let transport: any WiroHTTPTransport
    let socketSessionFactory: WiroSocketSessionFactory
    let logger: WiroLogger?
    let clock: WiroClock
    let nonceProvider: WiroNonceProvider
    let sleeper: WiroSleeper
    let jitterProvider: WiroJitterProvider

    // MARK: - Init (API key)

    /// Creates a client that authenticates with a Wiro API key.
    ///
    /// When `apiSecret` is provided, requests use signature auth
    /// (`x-nonce` + `x-signature`). Otherwise only `x-api-key` is sent.
    ///
    /// ```swift
    /// let client = try WiroClient(
    ///     apiKey: "your-api-key",
    ///     apiSecret: "optional-secret"
    /// )
    /// ```
    ///
    /// - Throws: `WiroError.validation` when credentials or URLs are
    ///   invalid.
    public init(
        apiKey: String,
        apiSecret: String? = nil,
        baseURL: URL = WiroClient.defaultBaseURL,
        socketURL: URL = WiroClient.defaultSocketURL,
        transport: any WiroHTTPTransport = URLSessionHTTPTransport(),
        pollInterval: Duration = .seconds(3),
        requestTimeout: Duration = .seconds(30),
        retryPolicy: WiroRetryPolicy = .default,
        logger: WiroLogger? = nil
    ) throws {
        try self.init(
            apiKey: apiKey,
            apiSecret: apiSecret,
            proxyHeaders: [:],
            authType: Self.resolveAuthType(apiSecret: apiSecret),
            baseURL: baseURL,
            socketURL: socketURL,
            transport: transport,
            socketSessionFactory: WiroClient.defaultSocketSessionFactory,
            pollInterval: pollInterval,
            requestTimeout: requestTimeout,
            retryPolicy: retryPolicy,
            logger: logger,
            clock: { Date() },
            nonceProvider: {
                String(Int64(Date().timeIntervalSince1970 * 1000))
            },
            sleeper: { duration in
                try await Task.sleep(for: duration)
            },
            jitterProvider: { Double.random(in: 0.8...1.2) }
        )
    }

    // MARK: - Init (proxy)

    /// Creates a client that sends REST requests through a proxy.
    ///
    /// No Wiro credentials are stored on device. `headers` are attached to
    /// every REST request. The WebSocket still connects directly to
    /// `socketURL` because task sockets authenticate with task tokens.
    ///
    /// > Important: Prefer proxy mode in shipped apps so long-lived API
    /// > secrets never embed in the binary.
    ///
    /// ```swift
    /// let client = try WiroClient(
    ///     proxyURL: URL(string: "https://api.myapp.com/wiro/v1")!,
    ///     headers: ["Authorization": "Bearer \(sessionToken)"]
    /// )
    /// ```
    ///
    /// - Throws: `WiroError.validation` when URLs are invalid.
    public init(
        proxyURL: URL,
        headers: [String: String] = [:],
        socketURL: URL = WiroClient.defaultSocketURL,
        transport: any WiroHTTPTransport = URLSessionHTTPTransport(),
        pollInterval: Duration = .seconds(3),
        requestTimeout: Duration = .seconds(30),
        retryPolicy: WiroRetryPolicy = .default,
        logger: WiroLogger? = nil
    ) throws {
        try self.init(
            apiKey: nil,
            apiSecret: nil,
            proxyHeaders: headers,
            authType: .proxy,
            baseURL: proxyURL,
            socketURL: socketURL,
            transport: transport,
            socketSessionFactory: WiroClient.defaultSocketSessionFactory,
            pollInterval: pollInterval,
            requestTimeout: requestTimeout,
            retryPolicy: retryPolicy,
            logger: logger,
            clock: { Date() },
            nonceProvider: {
                String(Int64(Date().timeIntervalSince1970 * 1000))
            },
            sleeper: { duration in
                try await Task.sleep(for: duration)
            },
            jitterProvider: { Double.random(in: 0.8...1.2) }
        )
    }

    /// Internal designated initializer with injectable seams for tests.
    init(
        apiKey: String?,
        apiSecret: String?,
        proxyHeaders: [String: String],
        authType: WiroAuthType,
        baseURL: URL,
        socketURL: URL,
        transport: any WiroHTTPTransport,
        socketSessionFactory: @escaping WiroSocketSessionFactory =
            WiroClient.defaultSocketSessionFactory,
        pollInterval: Duration,
        requestTimeout: Duration,
        retryPolicy: WiroRetryPolicy,
        logger: WiroLogger?,
        clock: @escaping WiroClock,
        nonceProvider: @escaping WiroNonceProvider,
        sleeper: @escaping WiroSleeper,
        jitterProvider: @escaping WiroJitterProvider
    ) throws {
        if authType != .proxy {
            let trimmedKey = apiKey?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmedKey.isEmpty else {
                throw WiroError.validation(
                    message: "apiKey must be a non-empty string.",
                    statusCode: 0,
                    responseBody: nil
                )
            }
            self.apiKey = trimmedKey

            if let secret = apiSecret {
                let trimmedSecret = secret.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard !trimmedSecret.isEmpty else {
                    throw WiroError.validation(
                        message:
                            "apiSecret must be a non-empty string when provided.",
                        statusCode: 0,
                        responseBody: nil
                    )
                }
                self.apiSecret = trimmedSecret
            } else {
                self.apiSecret = nil
            }
        } else {
            self.apiKey = nil
            self.apiSecret = nil
        }

        try WiroURLValidation.validate(
            baseURL,
            kind: .http,
            label: "baseURL"
        )
        try WiroURLValidation.validate(
            socketURL,
            kind: .webSocket,
            label: "socketURL"
        )

        self.authType = authType
        self.baseURL = WiroURLValidation.trimmingTrailingSlashes(baseURL)
        self.socketURL = socketURL
        self.proxyHeaders = proxyHeaders
        self.transport = transport
        self.socketSessionFactory = socketSessionFactory
        self.pollInterval = pollInterval
        self.requestTimeout = requestTimeout
        self.retryPolicy = retryPolicy
        self.logger = logger
        self.clock = clock
        self.nonceProvider = nonceProvider
        self.sleeper = sleeper
        self.jitterProvider = jitterProvider
    }

    private static func resolveAuthType(apiSecret: String?) -> WiroAuthType {
        guard let apiSecret else { return .apiKey }
        let trimmed = apiSecret.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmed.isEmpty ? .apiKey : .signature
    }

    // MARK: - Auth headers

    /// Builds authentication headers for a REST request.
    ///
    /// - Parameter includeContentType: When `true`, sets
    ///   `Content-Type: application/json`. Multipart uploads pass `false`.
    func authHeaders(includeContentType: Bool = true) -> [String: String] {
        var headers = [
            "User-Agent": "WiroKit/\(WiroKitInfo.version)",
        ]

        switch authType {
        case .apiKey:
            if let apiKey {
                headers["x-api-key"] = apiKey
            }
        case .signature:
            if let apiKey, let apiSecret {
                let nonce = nonceProvider()
                headers["x-api-key"] = apiKey
                headers["x-nonce"] = nonce
                headers["x-signature"] = Self.signature(
                    apiKey: apiKey,
                    apiSecret: apiSecret,
                    nonce: nonce
                )
            }
        case .proxy:
            for (key, value) in proxyHeaders {
                headers[key] = value
            }
        }

        if includeContentType {
            headers["Content-Type"] = "application/json"
        }
        return headers
    }

    /// HMAC-SHA256 signature as lowercase hex.
    ///
    /// `HMAC-SHA256(key: UTF8(apiKey), message: UTF8(apiSecret + nonce))`.
    static func signature(
        apiKey: String,
        apiSecret: String,
        nonce: String
    ) -> String {
        let key = SymmetricKey(data: Data(apiKey.utf8))
        let message = Data((apiSecret + nonce).utf8)
        let mac = HMAC<SHA256>.authenticationCode(
            for: message,
            using: key
        )
        return mac.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - POST helper

    /// Performs an authenticated JSON POST and parses the envelope.
    func post<T: Sendable>(
        _ path: String,
        body: WiroJSON,
        retryable: Bool = true,
        parse: @Sendable (WiroJSON) throws -> T
    ) async throws -> T {
        let url = try makeURL(path: path)
        let bodyData = try encodeBody(body)
        let timeoutSeconds = durationToTimeInterval(requestTimeout)

        var attempt = 0

        while true {
            try checkCancellation()

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = bodyData
            request.timeoutInterval = timeoutSeconds
            for (key, value) in authHeaders(includeContentType: true) {
                request.setValue(value, forHTTPHeaderField: key)
            }

            log(
                WiroLogEvent(
                    level: .debug,
                    message: "Starting request.",
                    method: "POST",
                    url: url.absoluteString,
                    retryCount: attempt
                )
            )

            let started = clock()
            let result: Result<(Data, HTTPURLResponse), WiroError>
            do {
                let response = try await transport.perform(request)
                result = .success(response)
            } catch let error as WiroError {
                result = .failure(error)
            } catch is CancellationError {
                throw WiroError.cancelled
            } catch {
                result = .failure(
                    .network(
                        message: "The network request failed.",
                        underlying: String(describing: type(of: error))
                    )
                )
            }

            let duration = durationSince(started)

            switch result {
            case .success(let (data, response)):
                let status = response.statusCode
                log(
                    WiroLogEvent(
                        level: .info,
                        message: "Request completed.",
                        method: "POST",
                        url: url.absoluteString,
                        statusCode: status,
                        duration: duration,
                        retryCount: attempt
                    )
                )

                let retryAfter = WiroResponseEnvelope
                    .retryAfterInterval(from: response)

                do {
                    let object = try WiroResponseEnvelope
                        .decodeSuccessObject(
                            data: data,
                            statusCode: status,
                            retryAfter: retryAfter
                        )
                    return try parse(object)
                } catch let error as WiroError {
                    try await retryOrThrow(
                        error: error,
                        attempt: &attempt,
                        retryable: retryable,
                        retryAfter: retryAfter,
                        url: url
                    )
                }

            case .failure(let error):
                if case .cancelled = error {
                    throw error
                }
                try await retryOrThrow(
                    error: error,
                    attempt: &attempt,
                    retryable: retryable,
                    retryAfter: nil,
                    url: url
                )
            }
        }
    }

    /// Handler for malformed nested JSON encountered while parsing.
    func malformedJSONHandler() -> JSONReader.MalformedJSONHandler {
        { [logger] raw in
            logger?(
                WiroLogEvent(
                    level: .debug,
                    message:
                        "Ignored malformed nested JSON string "
                        + "(length \(raw.count))."
                )
            )
        }
    }

    // MARK: - Helpers (shared with extensions)

    func makeURL(path: String) throws -> URL {
        let trimmedPath = path.hasPrefix("/") ? path : "/" + path
        let base = baseURL.absoluteString
        guard let url = URL(string: base + trimmedPath) else {
            throw WiroError.validation(
                message: "Could not build request URL for path \(path).",
                statusCode: 0,
                responseBody: nil
            )
        }
        return url
    }

    func encodeBody(_ body: WiroJSON) throws -> Data {
        do {
            return try JSONEncoder().encode(WiroJSONValue.object(body))
        } catch {
            throw WiroError.validation(
                message: "Could not encode request body as JSON.",
                statusCode: 0,
                responseBody: nil
            )
        }
    }

    func durationToTimeInterval(_ duration: Duration) -> TimeInterval {
        let components = duration.components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds)
            / 1_000_000_000_000_000_000
    }

    func checkCancellation() throws {
        do {
            try Task.checkCancellation()
        } catch {
            throw WiroError.cancelled
        }
    }

    func log(_ event: WiroLogEvent) {
        logger?(event)
    }

    func logFailure(
        _ error: WiroError,
        url: URL,
        attempt: Int
    ) {
        log(
            WiroLogEvent(
                level: .error,
                message: "Request failed.",
                method: "POST",
                url: url.absoluteString,
                retryCount: attempt,
                error: error.errorDescription
            )
        )
    }

    func durationSince(_ started: Date) -> Duration {
        let elapsed = clock().timeIntervalSince(started)
        return .seconds(max(0, elapsed))
    }

    func retryOrThrow(
        error: WiroError,
        attempt: inout Int,
        retryable: Bool,
        retryAfter: TimeInterval?,
        url: URL
    ) async throws {
        guard retryable, attempt < retryPolicy.maxRetries else {
            logFailure(error, url: url, attempt: attempt)
            throw error
        }

        guard let delay = retryDelay(
            for: error,
            attempt: attempt,
            headerRetryAfter: retryAfter
        ) else {
            logFailure(error, url: url, attempt: attempt)
            throw error
        }

        log(
            WiroLogEvent(
                level: .warning,
                message: "Retrying request after transient failure.",
                retryCount: attempt + 1,
                error: error.errorDescription
            )
        )

        try checkCancellation()
        do {
            try await sleeper(delay)
        } catch is CancellationError {
            throw WiroError.cancelled
        } catch let sleepError as WiroError {
            throw sleepError
        }
        try checkCancellation()
        attempt += 1
    }

    func retryDelay(
        for error: WiroError,
        attempt: Int,
        headerRetryAfter: TimeInterval?
    ) -> Duration? {
        let policyDelay = nextDelay(forRetryIndex: attempt)

        switch error {
        case .rateLimited(_, _, let associatedRetryAfter, _):
            let minimum = associatedRetryAfter ?? headerRetryAfter
            if let minimum {
                return maxDuration(policyDelay, .seconds(minimum))
            }
            return policyDelay

        case .unknownAPI(_, let statusCode, _):
            guard retryPolicy.shouldRetry(statusCode: statusCode) else {
                return nil
            }
            return policyDelay

        case .network, .timedOut:
            return policyDelay

        default:
            return nil
        }
    }

    func nextDelay(forRetryIndex index: Int) -> Duration {
        retryPolicy.delay(
            forRetryIndex: index,
            jitterFactor: jitterProvider()
        )
    }

    func maxDuration(_ lhs: Duration, _ rhs: Duration) -> Duration {
        lhs > rhs ? lhs : rhs
    }

    /// Executes a prepared request with retry / envelope handling.
    func execute<T: Sendable>(
        _ request: URLRequest,
        url: URL,
        retryable: Bool,
        transportCall: @Sendable (URLRequest) async throws -> (
            Data,
            HTTPURLResponse
        ),
        parse: @Sendable (WiroJSON) throws -> T
    ) async throws -> T {
        var attempt = 0
        var currentRequest = request

        while true {
            try checkCancellation()

            log(
                WiroLogEvent(
                    level: .debug,
                    message: "Starting request.",
                    method: currentRequest.httpMethod ?? "POST",
                    url: url.absoluteString,
                    retryCount: attempt
                )
            )

            // Refresh auth headers each attempt (signature nonce).
            for (key, value) in authHeaders(
                includeContentType: currentRequest.value(
                    forHTTPHeaderField: "Content-Type"
                )?.hasPrefix("application/json") == true
            ) {
                // Don't overwrite multipart Content-Type with JSON.
                if key == "Content-Type",
                   currentRequest.value(forHTTPHeaderField: "Content-Type")
                   != nil,
                   !(currentRequest.value(forHTTPHeaderField: "Content-Type")?
                       .hasPrefix("application/json") ?? false)
                {
                    continue
                }
                currentRequest.setValue(value, forHTTPHeaderField: key)
            }

            let started = clock()
            let result: Result<(Data, HTTPURLResponse), WiroError>
            do {
                let response = try await transportCall(currentRequest)
                result = .success(response)
            } catch let error as WiroError {
                result = .failure(error)
            } catch is CancellationError {
                throw WiroError.cancelled
            } catch {
                result = .failure(
                    .network(
                        message: "The network request failed.",
                        underlying: String(describing: type(of: error))
                    )
                )
            }

            let duration = durationSince(started)

            switch result {
            case .success(let (data, response)):
                let status = response.statusCode
                log(
                    WiroLogEvent(
                        level: .info,
                        message: "Request completed.",
                        method: currentRequest.httpMethod ?? "POST",
                        url: url.absoluteString,
                        statusCode: status,
                        duration: duration,
                        retryCount: attempt
                    )
                )

                let retryAfter = WiroResponseEnvelope
                    .retryAfterInterval(from: response)

                do {
                    let object = try WiroResponseEnvelope
                        .decodeSuccessObject(
                            data: data,
                            statusCode: status,
                            retryAfter: retryAfter
                        )
                    return try parse(object)
                } catch let error as WiroError {
                    try await retryOrThrow(
                        error: error,
                        attempt: &attempt,
                        retryable: retryable,
                        retryAfter: retryAfter,
                        url: url
                    )
                }

            case .failure(let error):
                if case .cancelled = error {
                    throw error
                }
                try await retryOrThrow(
                    error: error,
                    attempt: &attempt,
                    retryable: retryable,
                    retryAfter: nil,
                    url: url
                )
            }
        }
    }
}

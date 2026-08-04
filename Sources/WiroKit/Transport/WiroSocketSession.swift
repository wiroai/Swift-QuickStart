import Foundation

/// A decoded WebSocket frame from a Wiro task socket.
enum WiroSocketFrame: Sendable, Equatable {
    case text(String)
    case binary(Data)
}

/// Internal marker that the peer closed the socket (or local close raced).
struct WiroSocketClosedError: Error, Sendable {}

/// Injectable WebSocket session used by task tracking.
protocol WiroSocketSession: Sendable {
    /// Sends a UTF-8 text frame.
    func sendText(_ text: String) async throws
    /// Receives the next frame, or throws ``WiroSocketClosedError`` when
    /// the connection ends.
    func receiveFrame() async throws -> WiroSocketFrame
    /// Closes the socket. Safe to call multiple times.
    func close() async
}

/// Opens WebSocket sessions for ``WiroClient``.
typealias WiroSocketSessionFactory = @Sendable (
    _ url: URL,
    _ timeout: Duration
) async throws -> any WiroSocketSession

/// Converts a `Duration` to `TimeInterval` for URLSession APIs.
enum WiroSocketTiming {
    static func timeInterval(_ duration: Duration) -> TimeInterval {
        let components = duration.components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds)
            / 1_000_000_000_000_000_000
    }
}

/// `URLSessionWebSocketTask`-backed socket session.
actor URLSessionWebSocketSession: WiroSocketSession {
    private let task: URLSessionWebSocketTask
    private var isClosed = false

    init(task: URLSessionWebSocketTask) {
        self.task = task
    }

    static func connect(
        url: URL,
        timeout: Duration,
        session: URLSession = .shared
    ) -> URLSessionWebSocketSession {
        var request = URLRequest(
            url: url,
            timeoutInterval: WiroSocketTiming.timeInterval(timeout)
        )
        request.timeoutInterval = WiroSocketTiming.timeInterval(timeout)
        let webSocketTask = session.webSocketTask(with: request)
        let wrapper = URLSessionWebSocketSession(task: webSocketTask)
        webSocketTask.resume()
        return wrapper
    }

    func sendText(_ text: String) async throws {
        guard !isClosed else { throw WiroSocketClosedError() }
        do {
            try await task.send(.string(text))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw WiroError.webSocket(
                message: "Failed to send a WebSocket frame.",
                underlying: String(describing: type(of: error))
            )
        }
    }

    func receiveFrame() async throws -> WiroSocketFrame {
        guard !isClosed else { throw WiroSocketClosedError() }
        do {
            switch try await task.receive() {
            case .string(let text):
                return .text(text)
            case .data(let data):
                return .binary(data)
            @unknown default:
                throw WiroError.webSocket(
                    message:
                        "The Wiro task WebSocket returned an unsupported frame type.",
                    underlying: nil
                )
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as WiroError {
            throw error
        } catch {
            throw WiroSocketClosedError()
        }
    }

    func close() async {
        guard !isClosed else { return }
        isClosed = true
        task.cancel(with: .goingAway, reason: nil)
    }
}

extension WiroClient {
    /// Default factory that opens a ``URLSessionWebSocketSession``.
    static let defaultSocketSessionFactory: WiroSocketSessionFactory = {
        url,
        timeout in
        URLSessionWebSocketSession.connect(url: url, timeout: timeout)
    }
}

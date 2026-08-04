import Foundation

/// Performs HTTP requests for `WiroClient`.
///
/// Inject a mock in unit tests — production code uses
/// `URLSessionHTTPTransport` and never hits the network from tests.
public protocol WiroHTTPTransport: Sendable {
    /// Executes `request` and returns the response body with its HTTP
    /// metadata.
    ///
    /// - Parameter request: A fully configured `URLRequest`.
    /// - Returns: The response body and HTTP response.
    /// - Throws: Transport failures surfaced as `WiroError.network`.
    func perform(
        _ request: URLRequest
    ) async throws -> (Data, HTTPURLResponse)

    /// Uploads the contents of `fileURL` as the request body.
    ///
    /// Used for multipart uploads built on disk so large files are not
    /// buffered entirely in memory.
    func upload(
        _ request: URLRequest,
        fromFile fileURL: URL
    ) async throws -> (Data, HTTPURLResponse)
}

/// The default `URLSession`-backed transport.
public struct URLSessionHTTPTransport: WiroHTTPTransport {
    /// The session used for requests.
    public let session: URLSession

    /// Creates a transport wrapping `session`.
    ///
    /// - Parameter session: Defaults to `URLSession.shared`.
    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func perform(
        _ request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw WiroError.network(
                    message: "The server returned a non-HTTP response.",
                    underlying: nil
                )
            }
            return (data, http)
        } catch {
            throw Self.mapTransportError(error)
        }
    }

    public func upload(
        _ request: URLRequest,
        fromFile fileURL: URL
    ) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.upload(
                for: request,
                fromFile: fileURL
            )
            guard let http = response as? HTTPURLResponse else {
                throw WiroError.network(
                    message: "The server returned a non-HTTP response.",
                    underlying: nil
                )
            }
            return (data, http)
        } catch {
            throw Self.mapTransportError(error)
        }
    }

    /// Maps a transport-layer failure into `WiroError`.
    static func mapTransportError(_ error: Error) -> WiroError {
        if let wiro = error as? WiroError {
            return wiro
        }
        if error is CancellationError {
            return .cancelled
        }
        if let urlError = error as? URLError,
           urlError.code == .cancelled
        {
            return .cancelled
        }
        return .network(
            message: "The network request failed.",
            underlying: String(describing: type(of: error))
        )
    }
}

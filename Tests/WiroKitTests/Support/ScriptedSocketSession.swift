import Foundation
@testable import WiroKit

/// Scripted WebSocket session for unit tests.
actor ScriptedSocketSession: WiroSocketSession {
    private(set) var sentTexts: [String] = []
    private(set) var closeCount = 0
    private(set) var connectedURL: URL?
    private(set) var connectTimeout: Duration?

    private var frames: [Result<WiroSocketFrame, Error>] = []
    private var isClosed = false
    private var waiters: [CheckedContinuation<WiroSocketFrame, Error>] = []

    func configure(frames: [WiroSocketFrame], closeAfter: Bool = true) {
        self.frames = frames.map { .success($0) }
        if closeAfter {
            self.frames.append(.failure(WiroSocketClosedError()))
        }
    }

    func enqueue(_ frame: WiroSocketFrame) {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume(returning: frame)
        } else {
            frames.append(.success(frame))
        }
    }

    func markConnected(to url: URL, timeout: Duration) {
        connectedURL = url
        connectTimeout = timeout
    }

    func sendText(_ text: String) async throws {
        try ensureOpen()
        sentTexts.append(text)
    }

    func receiveFrame() async throws -> WiroSocketFrame {
        try Task.checkCancellation()
        try ensureOpen()
        if !frames.isEmpty {
            return try frames.removeFirst().get()
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.waiters.append(continuation)
        }
    }

    func close() async {
        guard !isClosed else { return }
        isClosed = true
        closeCount += 1
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.resume(throwing: WiroSocketClosedError())
        }
    }

    private func ensureOpen() throws {
        if isClosed {
            throw WiroSocketClosedError()
        }
    }
}

/// Owns a scripted session and exposes a ``WiroSocketSessionFactory``.
final class ScriptedSocketWorld: @unchecked Sendable {
    let session: ScriptedSocketSession

    init(session: ScriptedSocketSession = ScriptedSocketSession()) {
        self.session = session
    }

    var factory: WiroSocketSessionFactory {
        { [session] url, timeout in
            await session.markConnected(to: url, timeout: timeout)
            return session
        }
    }
}
